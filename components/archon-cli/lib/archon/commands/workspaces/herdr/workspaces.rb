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
      return stop_detached.call(arguments) if %w[stop kill].include?(action) && inside_herdr
      if action == 'kill'
        state_path = WorkspaceProjects.selection_path('herdr', home: home, state_home: state_home)
        return kill_all_sessions(capture, state_path: state_path)
      end
      if action == 'stop'
        Herdr.request(SESSION, ['session', 'stop', SESSION, '--json'], capture) if session_running?(capture)
        return 0
      end
      projects = Workspaces.select_projects('herdr', home: home, state_home: state_home, picker: picker)
      return 0 if projects.nil? || projects.empty?
      definitions = Workspaces.project_definitions(projects)
      running = session_running?(capture)
      state_path = WorkspaceProjects.selection_path('herdr', home: home, state_home: state_home)
      backend = create_herdr(definitions: definitions, state_path: state_path, running: running,
        capture: capture, run: run, start_server: start_server, ai: parsed[:ai])
      status = Workspaces.start_projects(definitions, backend)
      return status if status != 0 || inside_herdr || !tty
      Workspaces.attach_after_start(definitions, backend)
    rescue Interrupt
      puts 'Cancelled.'
      130
    rescue StandardError => error
      warn "Herdr workspace operation failed: #{error.message}"
      1
    end

    def run_detached_stop(arguments)
      Workspaces.run_detached_stop(arguments, module_path: __FILE__,
        entry_point: 'Archon::WorkspacesHerdr.run_workspaces_herdr', log_name: 'workspaces-herdr-stop.log')
    end
  end
end
