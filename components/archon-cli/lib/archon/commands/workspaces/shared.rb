require 'rbconfig'
require_relative 'help'
require_relative 'groups'
require_relative '../../shared/process'

module Archon
  module Workspaces
    extend self
    GROUPS = %w[general flashcards jslibs misc].freeze

    def run_command(command, arguments, stdio: :inherit)
      result = Shared.run_process(command, arguments, stdio: stdio)
      warn "Could not start command: #{result[:error].message}" if result[:error]
      result[:status] || 1
    end

    def parse_arguments(arguments, help:)
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
      parsed = { action: action, group: nil, ai: DEFAULT_AI }
      seen = []
      valid = options.length.even? && options.each_slice(2).all? do |flag, value|
        key = case flag
              when '--group', '-g' then :group if action != 'kill' && GROUPS.include?(value)
              when '--ai' then :ai if action == 'start' && AI_COMMANDS.key?(value)
              end
        next false unless key && !seen.include?(key)
        seen << key
        parsed[key] = value
        true
      end
      unless valid
        warn "Invalid workspace options: #{options.join(' ')}"
        warn "\n#{help}"
        return { status: 2 }
      end
      parsed
    end

    def manage_groups(action, group, backend, home: Dir.home, handlers: nil)
      handlers ||= {
        'general' => method(:manage_general), 'flashcards' => method(:manage_flashcards),
        'jslibs' => method(:manage_jslibs), 'misc' => method(:manage_misc)
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
        when 'misc' then session.start_with?('project-')
        else
          %w[main flashcards-fe flashcards-be].include?(session) || session.start_with?('jslib-', 'project-')
        end
      end
      session = sessions.include?('main') ? 'main' : sessions.first
      session ? backend.fetch(:attach_session).call(session) : 0
    end

    def run_detached_stop(arguments, module_path:, entry_point:, log_name:)
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
