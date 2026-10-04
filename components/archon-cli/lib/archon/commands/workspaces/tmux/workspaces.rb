require_relative 'tmux'

module Archon
  module WorkspacesTmux
    HELP = (Workspaces::ACTION_HELP.gsub('<backend>', 'tmux') +
      "\n\nStop closes all Archon-managed sessions on the current tmux server; unrelated sessions are preserved.").freeze

    def run_workspaces_tmux(arguments, home: Dir.home, state_home: ENV['XDG_STATE_HOME'], environment: ENV, tty: $stdin.tty?, tmux: nil,
                            capture: method(:capture_command), run: Workspaces.method(:run_command),
                            picker: WorkspaceProjects.method(:pick_projects), stop_detached: method(:run_detached_stop))
      parsed = Workspaces.parse_arguments(arguments, help: HELP)
      return parsed[:status] if parsed.key?(:status)
      action = parsed[:action]
      inside_tmux = !environment['TMUX'].to_s.empty?
      return stop_detached.call(arguments) if action == 'stop' && inside_tmux
      return stop_managed_sessions(run: run, capture: capture) if action == 'stop'
      projects = Workspaces.select_projects('tmux', home: home, state_home: state_home, picker: picker)
      return 0 if projects.nil? || projects.empty?
      definitions = Workspaces.project_definitions(projects)
      backend = tmux || create_tmux(run: run, capture: capture, ai: parsed[:ai])
      status = Workspaces.start_projects(definitions, backend)
      return status if status != 0 || inside_tmux || !tty
      Workspaces.attach_after_start(definitions, backend)
    rescue Interrupt
      puts 'Cancelled.'
      130
    rescue StandardError => error
      warn "tmux workspace operation failed: #{error.message}"
      1
    end

    def run_detached_stop(arguments)
      Workspaces.run_detached_stop(arguments, module_path: __FILE__,
        entry_point: 'Archon::WorkspacesTmux.run_workspaces_tmux', log_name: 'workspaces-tmux-stop.log')
    end
  end
end
