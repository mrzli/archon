require 'json'
require 'shellwords'
require_relative '../../shared/agent_restart'

module Archon
  module Claude
    extend self

    HELP = <<~TEXT.chomp.freeze
      Usage: archon claude restart

      Restart all Claude Code sessions in running Herdr and tmux sessions.
      Run from a separate shell with Claude sessions idle and input boxes empty.
      Each conversation resumes in its existing pane. No selection or confirmation.
    TEXT
    VALUE_OPTIONS = %w[--agent --agents --append-system-prompt --effort --fallback-model --model -n --name
                       --permission-mode --plugin-dir --setting-sources --settings --system-prompt].freeze
    LIST_OPTIONS = %w[--add-dir --allowedTools --allowed-tools --disallowedTools --disallowed-tools
                      --mcp-config --tools].freeze
    FLAGS = %w[--allow-dangerously-skip-permissions --chrome --dangerously-skip-permissions --ide --no-chrome
               --strict-mcp-config --verbose].freeze
    COMMANDS = %w[agents attach auth auto-mode doctor gateway import install kill logs mcp plugin plugins purge
                  respawn rm setup-token stop ultrareview update upgrade].freeze

    def run_claude(arguments, home: Dir.home, terminals: AgentTerminals, run: AgentTerminals.method(:run_process),
                   wait: -> { sleep 0.1 })
      if [%w[help], %w[-h], %w[--help], %w[restart --help], %w[restart -h]].include?(arguments)
        puts HELP
        return 0
      end
      unless arguments == ['restart']
        warn HELP
        return 2
      end
      # Claude takes about half a second to exit on TERM; KILL is only a fallback.
      AgentRestart.restart_agents(label: 'Claude', program: 'claude', terminals: terminals, run: run, wait: wait,
                                  term_grace: 3,
                                  prepare: ->(pane) { prepare(pane, home: home, terminals: terminals, run: run) })
    end

    def launch_options(argv)
      arguments = argv.drop(1)
      options = []
      first_operand = true
      until arguments.empty?
        argument = arguments.shift
        name, attached = argument.split('=', 2)
        if VALUE_OPTIONS.include?(name) || name == '--session-id'
          value = attached || arguments.shift
          raise "Missing value for #{name}." unless value
          options.concat([name, value]) unless name == '--session-id'
        elsif LIST_OPTIONS.include?(name)
          values = attached ? [attached] : []
          values << arguments.shift while arguments.any? && !arguments.first.start_with?('-')
          raise "Missing value for #{name}." if values.empty?
          options.concat([name, *values])
        elsif FLAGS.include?(argument)
          options << argument
        elsif %w[-c --continue --fork-session].include?(argument)
          next
        elsif %w[-r --resume].include?(name)
          arguments.shift unless attached || arguments.empty? || arguments.first.start_with?('-')
        elsif argument.start_with?('-')
          raise "Unsupported launch option #{argument}; session left running."
        else
          if first_operand && COMMANDS.include?(argument)
            raise "Unsupported Claude command #{argument}; process left running."
          end
          first_operand = false
        end
        # Original session selector and prompt are never replayed.
      end
      options
    end

    def prepare(pane, home:, terminals:, run:)
      info = terminals.process_info(pane, 'claude', run: run)
      raise 'No foreground Claude process; session left running.' unless info && info[:argv]
      raise 'Claude has no underlying shell to restart in; session left running.' if info[:no_shell]
      options = launch_options(info.fetch(:argv))
      session_id = session_id(home, info.fetch(:pid))
      # A session without a transcript has no conversation to resume.
      transcript = Dir.glob(File.join(home, '.claude', 'projects', '*', "#{session_id}.jsonl")).any?
      command = "cd -- #{Shellwords.escape(info.fetch(:cwd))} && " +
                Shellwords.join([info.fetch(:argv).first, *(transcript ? ['--resume', session_id] : []), *options])
      { pane: pane, info: info, command: command }
    end

    def session_id(home, pid)
      path = File.join(home, '.claude', 'sessions', "#{pid}.json")
      record = File.exist?(path) ? JSON.parse(File.read(path)) : {}
      id = record['sessionId']
      unless record['pid'] == Integer(pid) && id.is_a?(String) && id.match?(/\A[0-9a-f-]{36}\z/)
        raise "No Claude session record for process #{pid}; session left running."
      end
      id
    end
  end
end
