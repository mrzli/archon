require_relative '../../shared/process'
require_relative 'battery'

module Archon
  module Admin
    extend self

    HELP = <<~TEXT.chomp.freeze
      Usage: archon admin battery status
             archon admin battery conservation <on|off>
             archon admin voice <start|stop>

      Commands:
        battery conservation off  Allow a full battery charge (sudo)
        battery conservation on   Enable Lenovo battery conservation (sudo)
        battery status            Show charge, charging state, and conservation
        voice start  Start Voxtype dictation and load its configured model
        voice stop   Stop Voxtype dictation and release its model memory

      Voice commands preserve model files and login startup settings and need no sudo.
      Battery commands require Lenovo conservation support. No boot service is installed.
    TEXT

    def run_admin(arguments, run: Shared.method(:run_process), sys_root: '/sys')
      battery_commands = [%w[battery status], %w[battery conservation on], %w[battery conservation off]]
      battery_help = [%w[help battery], %w[battery help], %w[battery -h], %w[battery --help],
                      %w[battery conservation help], %w[battery conservation -h], %w[battery conservation --help]]
      battery_commands.each { |command| %w[-h --help].each { |flag| battery_help << [*command, flag] } }
      if battery_help.include?(arguments)
        puts HELP
        return 0
      end
      if battery_commands.include?(arguments)
        return run_battery(arguments.drop(1), run: run, sys_root: sys_root)
      end
      if [%w[help], %w[-h], %w[--help], %w[help voice],
          %w[voice help], %w[voice -h], %w[voice --help],
          %w[voice start -h], %w[voice start --help],
          %w[voice stop -h], %w[voice stop --help]].include?(arguments)
        puts HELP
        return 0
      end
      unless [%w[voice start], %w[voice stop]].include?(arguments)
        warn "Expected a battery or voice command.\n\n#{HELP}"
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
