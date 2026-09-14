require 'rbconfig'
require_relative 'help'
require_relative 'groups'

module Archon
  module Workspaces
    GROUPS = %w[general flashcards jslibs misc-projects].freeze

    def run_workspaces(arguments, home: Dir.home, environment: ENV, tty: $stdin.tty?, tmux: nil,
                       handlers: nil, run: method(:run_command), capture: method(:capture_command),
                       stop_detached: method(:run_detached_stop))
      if arguments.length == 1 && %w[help -h --help].include?(arguments.first)
        puts HELP.fetch('global')
        return 0
      end
      action, *options = arguments
      unless %w[start stop kill].include?(action)
        warn(action ? "Unknown workspace action: #{action}" : 'Missing workspace action.')
        warn "\n#{HELP.fetch('global')}"
        return 2
      end
      unless options.empty? || (action != 'kill' && options.length == 2 && %w[--group -g].include?(options.first) && GROUPS.include?(options.last))
        warn "Invalid workspace options: #{options.join(' ')}"
        warn "\n#{HELP.fetch('global')}"
        return 2
      end
      return run.call('tmux', ['kill-server']) if action == 'kill'
      return stop_detached.call(arguments) if action == 'stop' && !environment['TMUX'].to_s.empty?
      tmux ||= create_tmux(run: run, capture: capture)
      handlers ||= {
        'general' => method(:manage_general), 'flashcards' => method(:manage_flashcards),
        'jslibs' => method(:manage_jslibs), 'misc-projects' => method(:manage_misc_projects)
      }
      group = options.last
      groups = group ? [group] : action == 'start' ? GROUPS : GROUPS.reverse
      status = 0
      groups.each do |name|
        if handlers.fetch(name).call(action, tmux, home: home) != 0
          warn "Failed to #{action} tmux group: #{name}" unless group
          status = 1
        end
      end
      return status if status != 0 || action != 'start' || !environment['TMUX'].to_s.empty? || !tty
      attach_after_start(group, tmux)
    end

    def attach_after_start(group, tmux)
      result = tmux.fetch(:list_sessions).call
      if result[:status] != 0
        return 0 if result[:output].match?(/no server running|no sessions|error connecting/)
        warn "Failed to list tmux sessions: #{result[:output]}"
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
      session ? tmux.fetch(:attach_session).call(session) : 0
    end

    def run_detached_stop(arguments)
      directory = File.join(ENV.fetch('XDG_STATE_HOME', File.join(Dir.home, '.local/state')), 'archon')
      FileUtils.mkdir_p(directory)
      log = File.join(directory, 'workspaces-stop.log')
      File.open(log, File::WRONLY | File::CREAT | File::APPEND, 0o600) do |output|
        puts "Stopping workspaces independently; output: #{log}"
        $stdout.flush
        # Keep TMUX in the worker environment so tmux reaches the calling server.
        # Only the routing context is empty, preventing recursive detachment.
        code = 'exit Archon::Workspaces.run_workspaces(ARGV, environment: {})'
        pid = Process.spawn('setsid', '--wait', RbConfig.ruby, '-r', File.expand_path(__FILE__), '-e', code, '--', *arguments,
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
