require_relative '../workspaces/workspaces'

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

    def command_response(arguments, capture)
      result = capture.call('herdr', ['--session', SESSION, *arguments])
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

    def create_herdr(running:, capture:, run:, start_server:, ai: Workspaces::DEFAULT_AI)
      request = ->(arguments) { command_response(arguments, capture) }
      workspaces = running ? request.call(%w[workspace list]).fetch('workspaces') : []
      ensure_server = lambda do
        unless running
          start_server.call(capture)
          running = true
          workspaces.replace(request.call(%w[workspace list]).fetch('workspaces'))
        end
      end
      find_workspace = lambda do |name|
        matches = workspaces.select { |workspace| workspace.fetch('label') == name }
        raise "More than one Herdr workspace is named #{name}; rename duplicates before continuing." if matches.length > 1
        matches.first
      end
      create = lambda do |definition, tabs|
        result = create_workspace(definition, tabs, request)
        workspaces << result[:workspace] if result[:workspace]
        result
      end
      close = lambda do |name|
        workspace = find_workspace.call(name)
        next 0 unless workspace
        begin
          # Closing the last workspace with a client attached creates a new default
          # workspace. Stop the session instead, checking live IDs before shutdown.
          remaining = request.call(%w[workspace list]).fetch('workspaces')
          if remaining.map { |item| item.fetch('workspace_id') } == [workspace.fetch('workspace_id')]
            request.call(['session', 'stop', SESSION, '--json'])
          else
            request.call(['workspace', 'close', workspace.fetch('workspace_id')])
          end
          workspaces.delete(workspace)
          0
        rescue StandardError => error
          warn error.message
          1
        end
      end
      {
        name: 'Herdr', resource_label: 'Herdr workspace',
        has_session: ->(name) { ensure_server.call; !find_workspace.call(name).nil? },
        create_editor_session: ->(definition) { create.call(definition, Workspaces.editor_tabs(definition, ai: ai)) },
        create_shell_session: ->(definition) { create.call(definition, [{ name: 'shell' }])[:status] },
        stop_session: close, kill_session: close,
        list_sessions: -> { { status: 0, output: workspaces.map { |workspace| workspace.fetch('label') }.join("\n") } },
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
        created = request.call(['workspace', 'create', '--cwd', definition[:directory], '--label', definition[:session], '--no-focus'])
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
