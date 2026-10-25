require_relative '../../shared/process'

module Archon
  module Setup
    extend self

    # The Archon checkout that setup runs from, relative to the home directory.
    REPOSITORY = 'projects/personal/mrzli/archon'
    HELP = <<~TEXT.chomp.freeze
      Usage: archon setup

      Run Archon setup from ~/#{REPOSITORY}. Works from any directory.
    TEXT

    def run_setup(arguments, home: Dir.home, run: Shared.method(:run_process))
      if [%w[help], %w[-h], %w[--help]].include?(arguments)
        puts HELP
        return 0
      end
      unless arguments.empty?
        warn "Unexpected argument: #{arguments.first}\n\n#{HELP}"
        return 2
      end

      script = File.join(home, REPOSITORY, 'setup.sh')
      raise "Archon setup not found: #{script}" unless File.file?(script)
      result = run.call(script, [], stdio: :inherit)
      raise result[:error] if result[:error]
      raise "setup was terminated by #{result[:signal]}" if result[:signal]
      raise "setup exited with status #{result[:status]}" unless result[:status] == 0
      0
    rescue StandardError => error
      warn "Setup failed: #{error.message}"
      1
    end
  end
end
