require_relative '../shared'

module Archon
  module WorkspacesHerdr
    extend self
    SESSION = 'archon'

    def capture_command(command, arguments)
      result = Shared.run_process(command, arguments)
      output = if result[:error]
                 result[:error].message
               elsif result[:signal]
                 "Herdr was terminated by signal #{result[:signal]}"
               elsif result[:status] == 0
                 result[:stdout]
               else
                 "#{result[:stderr]}#{result[:stdout]}".strip
               end
      { status: result[:status] || 1, output: output }
    end

    def command_response(arguments, capture, session: SESSION)
      result = capture.call('herdr', ['--session', session, *arguments])
      raise "Herdr #{arguments.first(2).join(' ')} failed: #{result[:output]}" unless result[:status] == 0
      # pane run reports success through its exit status and prints no JSON.
      return nil if arguments.first(2) == %w[pane run]
      response = JSON.parse(result[:output])
      raise 'Herdr returned a non-object response.' unless response.is_a?(Hash)
      raise "Herdr: #{response.fetch('error')}" if response.key?('error')
      response.fetch('result', response)
    rescue JSON::ParserError => error
      raise "Could not read Herdr #{arguments.first(2).join(' ')} output: #{error.message}"
    end

    def kill_all_sessions(capture, state_path:)
      sessions = command_response(%w[session list --json], capture).fetch('sessions')
      status = 0
      reset_ids = sessions.none? { |session| session.fetch('name') == SESSION }
      sessions.each do |session|
        name = session.fetch('name')
        begin
          command_response(['session', 'stop', name, '--json'], capture, session: name) if session.fetch('running')
          if session.fetch('default')
            # Herdr cannot delete the default session: it shares the config directory.
            %w[session.json session-history.json].each do |file|
              File.unlink(File.join(session.fetch('session_dir'), file))
            rescue Errno::ENOENT
              next
            end
          else
            command_response(['session', 'delete', name, '--json'], capture, session: name)
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
      sessions = command_response(%w[session list --json], capture).fetch('sessions')
      sessions.any? { |session| session.fetch('name') == SESSION && session.fetch('running') }
    end

    def start_server(capture)
      directory = File.join(ENV.fetch('XDG_STATE_HOME', File.join(Dir.home, '.local/state')), 'archon')
      FileUtils.mkdir_p(directory)
      log = File.join(directory, 'workspaces-herdr-server.log')
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

    def create_herdr(definitions:, state_path:, running:, capture:, run:, start_server:, ai: Workspaces::DEFAULT_AI)
      request = ->(arguments) { command_response(arguments, capture) }
      selection = WorkspaceProjects.load_selection(state_path)
      workspace_ids = selection.fetch('workspace_ids', {})
      unless workspace_ids.is_a?(Hash) && workspace_ids.all? { |path, id| path.is_a?(String) && id.is_a?(String) }
        raise "Invalid saved Herdr workspace IDs: #{state_path}"
      end
      by_name = definitions.to_h { |definition| [definition[:session], definition] }
      remember_workspace = lambda do |definition, workspace|
        ids = workspace_ids.merge(definition[:directory] => workspace.fetch('workspace_id'))
        WorkspaceProjects.save_selection(state_path, selection.merge('workspace_ids' => ids))
        workspace_ids.replace(ids)
      end
      workspaces = running ? request.call(%w[workspace list]).fetch('workspaces') : []
      ensure_server = lambda do
        unless running
          start_server.call(capture)
          running = true
          workspaces.replace(request.call(%w[workspace list]).fetch('workspaces'))
        end
      end
      find_workspace = lambda do |name|
        definition = by_name.fetch(name)
        id = workspace_ids[definition[:directory]]
        workspace = workspaces.find { |item| item.fetch('workspace_id') == id }
        # Adopt the previous Archon label once, then identify projects by ID.
        matches = workspaces.select { |item| item.fetch('label') == name } unless workspace
        matches ||= []
        raise "More than one Herdr workspace is named #{name}; rename duplicates before continuing." if matches.length > 1
        workspace ||= matches.first
        if workspace
          if workspace.fetch('label') != definition[:label]
            request.call(['workspace', 'rename', workspace.fetch('workspace_id'), definition[:label]])
            workspace['label'] = definition[:label]
          end
          remember_workspace.call(definition, workspace) unless id == workspace.fetch('workspace_id')
        end
        workspace
      end
      {
        resource_label: 'Herdr workspace',
        has_session: ->(name) { ensure_server.call; !find_workspace.call(name).nil? },
        create_editor_session: ->(definition) {
          result = create_workspace(definition, Workspaces.editor_tabs(ai: ai), request) do |workspace|
            remember_workspace.call(definition, workspace)
          end
          workspaces << result[:workspace] if result[:workspace]
          result
        },
        attach_session: ->(name) {
          workspace = find_workspace.call(name)
          request.call(['workspace', 'focus', workspace.fetch('workspace_id')])
          run.call('herdr', ['--session', SESSION])
        }
      }
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
