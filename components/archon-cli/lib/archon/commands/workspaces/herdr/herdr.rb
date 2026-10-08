require 'digest'
require_relative '../shared'
require_relative '../../../shared/herdr'

module Archon
  module WorkspacesHerdr
    extend self
    SESSION = 'archon'

    def kill_all_sessions(capture, state_path:)
      sessions = Herdr.request(SESSION, %w[session list --json], capture).fetch('sessions')
      status = 0
      reset_ids = sessions.none? { |session| session.fetch('name') == SESSION }
      sessions.each do |session|
        name = session.fetch('name')
        begin
          Herdr.request(name, ['session', 'stop', name, '--json'], capture) if session.fetch('running')
          if session.fetch('default')
            # Herdr cannot delete the default session: it shares the config directory.
            %w[session.json session-history.json].each do |file|
              File.unlink(File.join(session.fetch('session_dir'), file))
            rescue Errno::ENOENT
              next
            end
          else
            Herdr.request(name, ['session', 'delete', name, '--json'], capture)
          end
          reset_ids = true if name == SESSION
        rescue StandardError => error
          warn error.message
          status = 1
        end
      end
      if reset_ids && File.exist?(state_path)
        selection = WorkspaceProjects.load_selection(state_path)
        selection.delete('workspace_ids')
        WorkspaceProjects.save_selection(state_path, selection)
      end
      status
    end

    def session_running?(capture)
      sessions = Herdr.request(SESSION, %w[session list --json], capture).fetch('sessions')
      sessions.any? { |session| session.fetch('name') == SESSION && session.fetch('running') }
    end

    # A stopping server still lists its session as running but refuses requests until it exits.
    def shutting_down?(capture)
      result = capture.call('herdr', ['--session', SESSION, 'workspace', 'list'])
      result[:status] != 0 && result[:output].include?('"server_unavailable"')
    end

    def wait_for_shutdown(capture, timeout: 10)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      while session_running?(capture)
        raise "Herdr session #{SESSION} is still shutting down; try again shortly" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep 0.05
      end
    end

    def stop_session(capture)
      return unless session_running?(capture)
      Herdr.request(SESSION, ['session', 'stop', SESSION, '--json'], capture) unless shutting_down?(capture)
      wait_for_shutdown(capture)
    end

    def ensure_server(capture, state_directory, start_server)
      wait_for_shutdown(capture) if session_running?(capture) && shutting_down?(capture)
      start_server.call(capture, state_directory) unless session_running?(capture)
    end

    def start_server(capture, state_directory)
      FileUtils.mkdir_p(state_directory)
      log = File.join(state_directory, 'workspaces-herdr-server.log')
      File.open(log, File::WRONLY | File::CREAT | File::APPEND, 0o600) do |output|
        environment = %w[HERDR_ENV HERDR_SOCKET_PATH HERDR_WORKSPACE_ID HERDR_TAB_ID HERDR_PANE_ID]
          .to_h { |key| [key, nil] }
        pid = Process.spawn(environment, 'setsid', 'herdr', '--session', SESSION, 'server',
                            in: File::NULL, out: output, err: output)
        waiter = Process.detach(pid)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
        loop do
          return if session_running?(capture)
          if (waiter.join(0) && !waiter.value.success?) || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            raise "Herdr session #{SESSION} did not start; see #{log}"
          end
          sleep 0.05
        end
      end
    end

    # session is an internal key; Herdr labels workspaces by folder name and Archon finds them by saved ID.
    def project_definitions(projects)
      projects.map do |directory|
        name = File.basename(directory).gsub(/[^a-zA-Z0-9_-]/, '-')
        { session: "archon-#{name}-#{Digest::SHA256.hexdigest(directory)[0, 12]}", directory: directory, label: File.basename(directory) }
      end
    end

    def create_herdr(state_path:, capture:, run:, ai: Workspaces::DEFAULT_AI)
      request = ->(arguments) { Herdr.request(SESSION, arguments, capture) }
      selection = WorkspaceProjects.load_selection(state_path)
      workspace_ids = selection.fetch('workspace_ids', {})
      unless workspace_ids.is_a?(Hash) && workspace_ids.all? { |path, id| path.is_a?(String) && id.is_a?(String) }
        raise "Invalid saved Herdr workspace IDs: #{state_path}"
      end
      remember_workspace = lambda do |definition, workspace|
        ids = workspace_ids.merge(definition[:directory] => workspace.fetch('workspace_id'))
        WorkspaceProjects.save_selection(state_path, selection.merge('workspace_ids' => ids))
        workspace_ids.replace(ids)
      end
      workspaces = request.call(%w[workspace list]).fetch('workspaces')
      find_workspace = lambda do |definition|
        id = workspace_ids[definition[:directory]]
        workspace = workspaces.find { |item| item.fetch('workspace_id') == id }
        if workspace && workspace.fetch('label') != definition[:label]
          request.call(['workspace', 'rename', workspace.fetch('workspace_id'), definition[:label]])
          workspace['label'] = definition[:label]
        end
        workspace
      end
      {
        resource_label: 'Herdr workspace',
        has_session: ->(definition) { !find_workspace.call(definition).nil? },
        start_existing_session: ->(definition) {
          start_existing_tools(find_workspace.call(definition).fetch('workspace_id'), request)
        },
        create_editor_session: ->(definition) {
          result = create_workspace(definition, Workspaces.editor_tabs(ai: ai), request) do |workspace|
            remember_workspace.call(definition, workspace)
          end
          workspaces << result[:workspace] if result[:workspace]
          result
        },
        attach_session: ->(definition) {
          workspace = find_workspace.call(definition)
          request.call(['workspace', 'focus', workspace.fetch('workspace_id')])
          run.call('herdr', ['--session', SESSION])
        }
      }
    end

    def start_existing_tools(workspace_id, request)
      tabs = request.call(['tab', 'list', '--workspace', workspace_id]).fetch('tabs')
      panes = request.call(['pane', 'list', '--workspace', workspace_id]).fetch('panes')
      panes.each do |pane|
        tab = tabs.find { |item| item.fetch('tab_id') == pane.fetch('tab_id') }
        next unless tab && tab.fetch('pane_count') == 1
        command = Workspaces::TAB_COMMANDS[tab.fetch('label')]
        # Native agent restores can be pending before a client attaches.
        next unless command && !pane['agent']
        pane_id = pane.fetch('pane_id')
        info = request.call(['pane', 'process-info', '--pane', pane_id]).fetch('process_info')
        next unless Herdr.idle_shell?(info)
        request.call(['pane', 'run', pane_id, command])
      end
      { status: 0 }
    rescue StandardError => error
      warn error.message
      { status: 1 }
    end

    def create_workspace(definition, tabs, request)
      workspace_id = nil
      begin
        created = request.call(['workspace', 'create', '--cwd', definition[:directory], '--label', definition[:label], '--no-focus'])
        workspace = created.fetch('workspace')
        workspace_id = workspace.fetch('workspace_id')
        first_tab = created.fetch('tab').fetch('tab_id')
        request.call(['tab', 'rename', first_tab, tabs.first[:name]])
        tabs.each_with_index do |tab, index|
          created_tab = if index.zero?
                          created
                        else
                          request.call(['tab', 'create', '--workspace', workspace_id, '--cwd', definition[:directory], '--label', tab[:name], '--no-focus'])
                        end
          request.call(['pane', 'run', created_tab.fetch('root_pane').fetch('pane_id'), tab[:command]]) if tab[:command]
        end
        yield workspace if block_given?
        { status: 0, workspace: workspace }
      rescue StandardError => error
        warn error.message
        return { status: 1 } unless workspace_id
        begin
          request.call(['workspace', 'close', workspace_id])
          { status: 1, cleanup_status: 0 }
        rescue StandardError => cleanup_error
          warn cleanup_error.message
          { status: 1, cleanup_status: 1 }
        end
      end
    end
  end
end
