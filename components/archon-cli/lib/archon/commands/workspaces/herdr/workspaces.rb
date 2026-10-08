require_relative 'herdr'

module Archon
  module WorkspacesHerdr
    HELP = (Workspaces::ACTION_HELP.gsub('<backend>', 'herdr') +
      "\n\nUses the dedicated Herdr session 'archon'. Stop shuts down that entire session.\nKill stops ALL Herdr sessions and clears their saved layouts.").freeze

    def run_workspaces_herdr(arguments, home: Dir.home, state_home: ENV['XDG_STATE_HOME'], environment: ENV, tty: $stdin.tty?,
                             capture: Workspaces.method(:capture_command), run: Workspaces.method(:run_command),
                             start_server: method(:start_server), picker: WorkspaceProjects.method(:pick_projects), stop_detached: method(:run_detached_stop))
      parsed = Workspaces.parse_arguments(arguments, help: HELP)
      return parsed[:status] if parsed.key?(:status)
      action = parsed[:action]
      inside_herdr = environment['HERDR_ENV'] == '1'
      state_directory = WorkspaceProjects.state_directory(home: home, state_home: state_home)
      state_path = WorkspaceProjects.selection_path('herdr', home: home, state_home: state_home)
      return stop_detached.call(arguments, state_directory) if %w[kill restart stop].include?(action) && inside_herdr
      return kill_all_sessions(capture, state_path: state_path) if action == 'kill'
      marker = Workspaces.restart_marker(state_directory, 'herdr')
      restart_started = Time.now.to_f
      Workspaces.mark_restart(marker, started_at: restart_started, finished: false) if action == 'restart'
      begin
        if %w[restart stop].include?(action)
          stop_session(capture)
          return 0 if action == 'stop'
        end
        projects = if action == 'restart'
                     Workspaces.saved_projects('herdr', home: home, state_home: state_home)
                   else
                     Workspaces.select_projects('herdr', home: home, state_home: state_home, picker: picker)
                   end
        return 0 if projects.nil? || projects.empty?
        definitions = project_definitions(projects)
        ensure_server(capture, state_directory, start_server)
        backend = create_herdr(state_path: state_path, capture: capture, run: run, ai: parsed[:ai])
        status = Workspaces.start_projects(definitions, backend)
      ensure
        Workspaces.mark_restart(marker, started_at: restart_started, finished: true) if action == 'restart'
      end
      return status if status != 0 || inside_herdr || !tty
      loop do
        attached_at = Time.now.to_f
        status = Workspaces.attach_after_start(definitions, backend)
        # A restart from inside Herdr closes this client; reattach once it has finished.
        return status unless Workspaces.wait_for_restart(marker, since: attached_at) && session_running?(capture)
        backend = create_herdr(state_path: state_path, capture: capture, run: run, ai: parsed[:ai])
      end
    rescue Interrupt
      puts 'Cancelled.'
      130
    rescue StandardError => error
      warn "Herdr workspace operation failed: #{error.message}"
      1
    end

    def run_detached_stop(arguments, state_directory)
      Workspaces.run_detached_stop(arguments, module_path: __FILE__, entry_point: 'Archon::WorkspacesHerdr.run_workspaces_herdr',
        log: File.join(state_directory, 'workspaces-herdr-stop.log'))
    end
  end
end
