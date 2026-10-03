require 'shellwords'
require_relative 'terminals'

module Archon
  module Codex
    extend self

    HELP = <<~TEXT.chomp.freeze
      Usage: archon codex restart

      Restart all Codex CLI sessions in running Herdr and tmux sessions.
      Run from a separate shell with Codex sessions idle and input boxes empty.
      The latest conversation in each directory resumes in its existing pane. No selection or confirmation.
    TEXT
    VALUE_OPTIONS = %w[-c --config --enable --disable --remote --remote-auth-token-env
                       -m --model --local-provider -p --profile -s --sandbox --add-dir
                       -a --ask-for-approval].freeze
    FLAGS = %w[--strict-config --oss --approve-for-me --dangerously-bypass-approvals-and-sandbox
               --dangerously-bypass-hook-trust --search --no-alt-screen --no-daemon].freeze
    NON_INTERACTIVE = %w[agents exec e review login logout mcp plugin app-server remote-control completion
                         update doctor sandbox debug apply a queue archive delete migrate-rollouts
                         unarchive cloud exec-server features help].freeze

    def run_codex(arguments, terminals: Terminals, run: Terminals.method(:run_process),
                  wait: -> { sleep 0.1 })
      if [%w[help], %w[-h], %w[--help], %w[restart --help], %w[restart -h]].include?(arguments)
        puts HELP
        return 0
      end
      unless arguments == ['restart']
        warn HELP
        return 2
      end
      panes, failures = terminals.discover(run: run)
      failures.each { |failure| warn failure }
      return 1 unless failures.empty?
      if panes.empty?
        puts 'No Codex CLI sessions running.'
        return 0
      end
      # Validate the whole batch before stopping any processes.
      jobs = panes.map { |pane| prepare(pane, terminals: terminals, run: run) }
      puts "Restarting #{jobs.length} Codex sessions..."
      $stdout.flush
      jobs.each do |job|
        begin
          terminals.terminate(job[:info], 'TERM')
        rescue StandardError => error
          failures << error.message
        end
      end
      wait.call
      jobs.each do |job|
        begin
          terminals.terminate(job[:info], 'KILL') if terminals.running?(job[:info])
        rescue StandardError => error
          failures << error.message
        end
      end
      # One short batch-wide grace period for shells to reclaim their terminals.
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
      while jobs.any? { |job| terminals.running?(job[:info]) }
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        wait.call
      end
      sent = 0
      jobs.each do |job|
        pane = job[:pane]
        begin
          unless terminals.process_info(pane, run: run)&.fetch(:shell, false)
            raise 'The pane has not returned to its shell.'
          end
          terminals.submit(pane, job[:command], run: run)
          sent += 1
        rescue StandardError => error
          failures << "#{pane[:backend]} #{pane[:server]} #{pane[:id]}: #{error.message} Recovery command: #{job[:command]}"
        end
      end
      failures.each { |failure| warn failure }
      puts "Sent restart commands to #{sent}/#{jobs.length} Codex panes."
      failures.empty? ? 0 : 1
    rescue Interrupt
      warn "Codex restart cancelled."
      130
    rescue StandardError => error
      warn "Codex restart failed: #{error.message}"
      1
    end

    def resume_options(argv)
      arguments = argv.drop(1)
      options = []
      first_operand = true
      until arguments.empty?
        argument = arguments.shift
        name, attached = argument.split('=', 2)
        if VALUE_OPTIONS.include?(name) || %w[-C --cd -i --image].include?(name)
          value = attached || arguments.shift
          raise "Missing value for #{name}." unless value
          options.concat([name, value]) unless %w[-i --image].include?(name)
        elsif FLAGS.include?(argument)
          options << argument
        elsif %w[--last --all --include-non-interactive].include?(argument)
          next
        elsif argument.start_with?('-')
          raise "Unsupported launch option #{argument}; session left running."
        else
          if first_operand && NON_INTERACTIVE.include?(argument)
            raise "Unsupported Codex command #{argument}; process left running."
          end
          first_operand = false
        end
        # Original subcommand, session selector and prompt are never replayed.
      end
      options
    end

    def prepare(pane, terminals:, run:)
      info = terminals.process_info(pane, run: run)
      raise 'No foreground Codex process; session left running.' unless info && info[:argv]
      raise 'Codex has no underlying shell to restart in; session left running.' if info[:no_shell]
      options = resume_options(info.fetch(:argv))
      options.concat(['-C', info.fetch(:cwd)]) unless options.any? { |option| %w[-C --cd].include?(option) }
      command = "cd -- #{Shellwords.escape(info.fetch(:cwd))} && " +
                Shellwords.join([info.fetch(:argv).first, 'resume', '--last', *options])
      { pane: pane, info: info, command: command }
    end
  end
end
