require 'rbconfig'
require_relative 'help'
require_relative 'groups'

module Archon
  module Workspaces
    GROUPS = %w[general flashcards jslibs misc-projects].freeze

    def run_workspaces(arguments, home: Dir.home, environment: ENV, tty: $stdin.tty?, tmux: nil,
                       handlers: nil, run: method(:run_command), capture: method(:capture_command),
                       stop_detached: method(:run_detached_stop))
      parsed = parse_arguments(arguments)
      return parsed[:status] if parsed.key?(:status)
      action, group = parsed.values_at(:action, :group)
      return run.call('tmux', ['kill-server']) if action == 'kill'
      return stop_detached.call(arguments) if action == 'stop' && !environment['TMUX'].to_s.empty?
      tmux ||= create_tmux(run: run, capture: capture)
      status = manage_groups(action, group, tmux, home: home, handlers: handlers)
      return status if status != 0 || action != 'start' || !environment['TMUX'].to_s.empty? || !tty
      attach_after_start(group, tmux)
    end

    def parse_arguments(arguments, help: HELP.fetch('global'))
      if arguments.length == 1 && %w[help -h --help].include?(arguments.first)
        puts help
        return { status: 0 }
      end
      action, *options = arguments
      unless %w[start stop kill].include?(action)
        warn(action ? "Unknown workspace action: #{action}" : 'Missing workspace action.')
        warn "\n#{help}"
        return { status: 2 }
      end
      unless options.empty? || (action != 'kill' && options.length == 2 && %w[--group -g].include?(options.first) && GROUPS.include?(options.last))
        warn "Invalid workspace options: #{options.join(' ')}"
        warn "\n#{help}"
        return { status: 2 }
      end
      { action: action, group: options.last }
    end

    def manage_groups(action, group, backend, home: Dir.home, handlers: nil)
      handlers ||= {
        'general' => method(:manage_general), 'flashcards' => method(:manage_flashcards),
        'jslibs' => method(:manage_jslibs), 'misc-projects' => method(:manage_misc_projects)
      }
      groups = group ? [group] : action == 'start' ? GROUPS : GROUPS.reverse
      status = 0
      groups.each do |name|
        if handlers.fetch(name).call(action, backend, home: home) != 0
          warn "Failed to #{action} #{backend.fetch(:name, 'tmux')} group: #{name}" unless group
          status = 1
        end
      end
      status
    end

    def attach_after_start(group, backend)
      result = backend.fetch(:list_sessions).call
      if result[:status] != 0
        return 0 if result[:output].match?(/no server running|no sessions|error connecting/)
        warn "Failed to list #{backend.fetch(:resource_label, 'tmux session')}s: #{result[:output]}"
        return 1
      end
      sessions = result[:output].lines(chomp: true).select do |session|
        case group
        when 'general' then session == 'main'
        when 'flashcards' then %w[flashcards-fe flashcards-be].include?(session)
        when 'jslibs' then session.start_with?('jslib-')
        when 'misc-projects' then session.start_with?('project-')
        else
          %w[main flashcards-fe flashcards-be].include?(session) || session.start_with?('jslib-', 'project-')
        end
      end
      session = sessions.include?('main') ? 'main' : sessions.first
      session ? backend.fetch(:attach_session).call(session) : 0
    end

    def run_detached_stop(arguments, module_path: __FILE__, entry_point: 'Archon::Workspaces.run_workspaces', log_name: 'workspaces-stop.log')
      directory = File.join(ENV.fetch('XDG_STATE_HOME', File.join(Dir.home, '.local/state')), 'archon')
      FileUtils.mkdir_p(directory)
      log = File.join(directory, log_name)
      File.open(log, File::WRONLY | File::CREAT | File::APPEND, 0o600) do |output|
        puts "Stopping workspaces independently; output: #{log}"
        $stdout.flush
        # Preserve the calling server environment, but clear the routing context
        # to prevent recursive detachment.
        code = "exit #{entry_point}(ARGV, environment: {})"
        pid = Process.spawn('setsid', '--wait', RbConfig.ruby, '-r', File.expand_path(module_path), '-e', code, '--', *arguments,
                            in: File::NULL, out: output, err: output)
        _, result = Process.wait2(pid)
        status = result.exitstatus || 1
        warn "Workspace shutdown failed; see #{log}" unless status == 0
        status
      end
    rescue SystemCallError => error
      warn "Could not start workspace shutdown: #{error.message}"
      1
    end
  end
end
