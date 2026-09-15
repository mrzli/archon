require_relative '../../shared/process'

module Archon
  module Admin
    extend self

    HELP = <<~TEXT.chomp.freeze
      Usage: archon admin voice <start|stop>

      Commands:
        voice start  Start Voxtype dictation and load its configured model
        voice stop   Stop Voxtype dictation and release its model memory

      Model files and login startup settings are preserved. No sudo is needed.
    TEXT

    def run_admin(arguments, run: Shared.method(:run_process))
      if [%w[help], %w[-h], %w[--help], %w[help voice],
          %w[voice help], %w[voice -h], %w[voice --help],
          %w[voice start -h], %w[voice start --help],
          %w[voice stop -h], %w[voice stop --help]].include?(arguments)
        puts HELP
        return 0
      end
      unless [%w[voice start], %w[voice stop]].include?(arguments)
        warn "Expected voice start or voice stop.\n\n#{HELP}"
        return 2
      end

      action = arguments.last
      result = run.call('systemctl', ['--user', action, 'voxtype.service'], stdio: :inherit)
      raise result[:error] if result[:error]
      raise "systemctl was terminated by #{result[:signal]}" if result[:signal]
      raise "systemctl exited with status #{result[:status]}" unless result[:status] == 0

      puts "Voxtype #{action == 'start' ? 'started' : 'stopped'}."
      0
    rescue StandardError => error
      warn "Voice operation failed: #{error.message}"
      1
    end
  end
end
