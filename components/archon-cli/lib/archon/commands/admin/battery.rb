require_relative '../../shared/process'

module Archon
  module Admin
    extend self

    def run_battery(arguments, run: Shared.method(:run_process), sys_root: '/sys')
      control = File.join(sys_root, 'bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode')
      unless File.file?(control)
        raise 'Lenovo battery conservation control is unavailable on this machine.'
      end

      if arguments == ['status']
        battery = File.join(sys_root, 'class/power_supply/BAT0')
        charge = File.read(File.join(battery, 'capacity')).strip
        state = File.read(File.join(battery, 'status')).strip
        enabled = conservation_enabled?(control)
        puts "Battery: #{charge}% (#{state})"
        puts "Conservation: #{enabled ? 'on' : 'off'}"
      else
        value = arguments.last == 'on' ? '1' : '0'
        if conservation_enabled?(control) != (value == '1')
          result = run.call('sudo', ['sh', '-c', 'printf "%s\\n" "$1" > "$2"',
                                     'archon-battery', value, control], stdio: :inherit)
          raise result[:error] if result[:error]
          raise "sudo was terminated by #{result[:signal]}" if result[:signal]
          raise "sudo exited with status #{result[:status]}" unless result[:status] == 0
          unless conservation_enabled?(control) == (value == '1')
            raise 'Conservation setting did not change to the requested state.'
          end
        end
        puts "Battery conservation #{arguments.last}."
      end
      0
    rescue StandardError => error
      warn "Battery operation failed: #{error.message}"
      1
    end

    def conservation_enabled?(control)
      value = File.read(control).strip
      raise "Unexpected conservation setting: #{value.inspect}" unless %w[0 1].include?(value)

      value == '1'
    end
  end
end
