require_relative 'herdr'

module Archon
  module WorkspacesHerdr
    HELP = (Workspaces::ACTION_HELP.gsub('<backend>', 'herdr') +
      "\n\nUses the dedicated Herdr session 'archon'.\n" +
      "Stop also shuts down that session when no workspaces remain.\n" +
      "The kill action stops that entire session, including any extra workspaces in it.").freeze

    def run_workspaces_herdr(arguments, home: Dir.home, state_home: ENV['XDG_STATE_HOME'], environment: ENV, tty: $stdin.tty?,
                             capture: method(:capture_command), run: Workspaces.method(:run_command),
                             start_server: method(:start_server), picker: WorkspaceProjects.method(:pick_projects), stop_detached: method(:run_detached_stop))
      parsed = Workspaces.parse_arguments(arguments, help: HELP)
      return parsed[:status] if parsed.key?(:status)
      action = parsed[:action]
      inside_herdr = environment['HERDR_ENV'] == '1'
      return stop_detached.call(arguments) if %w[stop kill].include?(action) && inside_herdr
      projects = action == 'start' ? Workspaces.select_projects('herdr', home: home, state_home: state_home, picker: picker) : WorkspaceProjects.discover_projects(home)
      return 0 if action == 'start' && (projects.nil? || projects.empty?)
      definitions = Workspaces.project_definitions(projects)
      running = session_running?(capture)
      if action == 'kill'
        command_response(['session', 'stop', SESSION, '--json'], capture) if running
        return 0
      end
      backend = create_herdr(running: running, capture: capture, run: run, start_server: start_server, ai: parsed[:ai])
      status = action == 'start' ? Workspaces.start_projects(definitions, backend) : Workspaces.stop_projects(definitions, backend)
      if action == 'stop' && status == 0 && running && session_running?(capture)
        remaining = command_response(%w[workspace list], capture).fetch('workspaces')
        command_response(['session', 'stop', SESSION, '--json'], capture) if remaining.empty?
      end
      return status if status != 0 || action != 'start' || inside_herdr || !tty
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
