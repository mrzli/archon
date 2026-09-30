require_relative 'tmux'

module Archon
  module WorkspacesTmux
    HELP = (Workspaces::ACTION_HELP.gsub('<backend>', 'tmux') +
      "\n\nThe kill action stops the entire tmux server, including sessions outside Archon's workspace groups.").freeze

    def run_workspaces_tmux(arguments, home: Dir.home, environment: ENV, tty: $stdin.tty?, tmux: nil,
                            capture: method(:capture_command), run: Workspaces.method(:run_command),
                            handlers: nil, stop_detached: method(:run_detached_stop))
      parsed = Workspaces.parse_arguments(arguments, help: HELP)
      return parsed[:status] if parsed.key?(:status)
      action, group = parsed.values_at(:action, :group)
      return run.call('tmux', ['kill-server']) if action == 'kill'
      inside_tmux = !environment['TMUX'].to_s.empty?
      return stop_detached.call(arguments) if action == 'stop' && inside_tmux
      backend = tmux || create_tmux(run: run, capture: capture, ai: parsed[:ai])
      status = Workspaces.manage_groups(action, group, backend, home: home, handlers: handlers)
      return status if status != 0 || action != 'start' || inside_tmux || !tty
      Workspaces.attach_after_start(group, backend)
    end

    def run_detached_stop(arguments)
      Workspaces.run_detached_stop(arguments, module_path: __FILE__,
        entry_point: 'Archon::WorkspacesTmux.run_workspaces_tmux', log_name: 'workspaces-tmux-stop.log')
    end
  end
end
