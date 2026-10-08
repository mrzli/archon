require_relative 'tmux'

module Archon
  module WorkspacesTmux
    HELP = (Workspaces::ACTION_HELP.gsub('<backend>', 'tmux') +
      "\n\nStop closes all Archon-managed sessions on the current tmux server; unrelated sessions are preserved.\nKill stops the ENTIRE current tmux server, including unrelated sessions.").freeze

    def run_workspaces_tmux(arguments, home: Dir.home, state_home: ENV['XDG_STATE_HOME'], environment: ENV, tty: $stdin.tty?,
                            capture: Workspaces.method(:capture_command), run: Workspaces.method(:run_command),
                            picker: WorkspaceProjects.method(:pick_projects), stop_detached: method(:run_detached_stop))
      parsed = Workspaces.parse_arguments(arguments, help: HELP)
      return parsed[:status] if parsed.key?(:status)
      action = parsed[:action]
      inside_tmux = !environment['TMUX'].to_s.empty?
      state_directory = WorkspaceProjects.state_directory(home: home, state_home: state_home)
      return stop_detached.call(arguments, state_directory) if %w[kill restart stop].include?(action) && inside_tmux
      return kill_server(capture) if action == 'kill'
      marker = Workspaces.restart_marker(state_directory, 'tmux')
      restart_started = Time.now.to_f
      Workspaces.mark_restart(marker, started_at: restart_started, finished: false) if action == 'restart'
      begin
        if %w[restart stop].include?(action)
          status = stop_managed_sessions(run: run, capture: capture)
          return status if action == 'stop' || status != 0
        end
        projects = if action == 'restart'
                     Workspaces.saved_projects('tmux', home: home, state_home: state_home)
                   else
                     Workspaces.select_projects('tmux', home: home, state_home: state_home, picker: picker)
                   end
        return 0 if projects.nil? || projects.empty?
        definitions = project_definitions(projects)
        wait_for_server_exit(capture)
        backend = create_tmux(run: run, capture: capture, ai: parsed[:ai])
        status = Workspaces.start_projects(definitions, backend)
      ensure
        Workspaces.mark_restart(marker, started_at: restart_started, finished: true) if action == 'restart'
      end
      return status if status != 0 || inside_tmux || !tty
      loop do
        attached_at = Time.now.to_f
        status = Workspaces.attach_after_start(definitions, backend)
        # A restart from inside tmux closes this client; reattach once it has finished.
        return status unless Workspaces.wait_for_restart(marker, since: attached_at)
      end
    rescue Interrupt
      puts 'Cancelled.'
      130
    rescue StandardError => error
      warn "tmux workspace operation failed: #{error.message}"
      1
    end

    def run_detached_stop(arguments, state_directory)
      Workspaces.run_detached_stop(arguments, module_path: __FILE__, entry_point: 'Archon::WorkspacesTmux.run_workspaces_tmux',
        log: File.join(state_directory, 'workspaces-tmux-stop.log'))
    end
  end
end
