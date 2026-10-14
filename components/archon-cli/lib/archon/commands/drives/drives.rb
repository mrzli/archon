require 'json'
require_relative '../../shared/process'
require_relative '../workspaces/project_picker'

module Archon
  module Drives
    extend self

    HELP = <<~TEXT.chomp.freeze
      Usage: archon drives eject
             archon drives list

      Commands:
        eject  Choose a drive, unmount its filesystems, and power it off
        list   Show removable drives, their partitions, and mount points

      Requires lsblk. Eject also requires udisksctl and an interactive terminal.
    TEXT

    def run_drives(arguments, run: Shared.method(:run_process), picker: method(:pick_drive))
      help = [%w[help], %w[-h], %w[--help]]
      %w[eject list].each { |command| help.push(['help', command], [command, '-h'], [command, '--help']) }
      if help.include?(arguments)
        puts HELP
        return 0
      end
      unless [%w[eject], %w[list]].include?(arguments)
        warn "Expected eject or list.\n\n#{HELP}"
        return 2
      end

      drives = removable_drives(run)
      if drives.empty?
        puts 'No removable drives.'
        return 0
      end
      if arguments == ['list']
        drives.each_with_index do |drive, index|
          puts if index > 0
          puts "#{drive_name(drive)}  #{drive['size']}  #{drive['path']}"
          volumes(drive).each do |volume|
            mounts = mount_points(volume)
            fields = [volume['path'], volume['label'], volume['fstype'], mounts.empty? ? 'not mounted' : mounts.join(', ')]
            puts "  #{fields.compact.join('  ')}"
          end
        end
        return 0
      end

      index = picker.call(drives.map { |drive| picker_label(drive) })
      unless index
        puts 'Cancelled.'
        return 0
      end
      drive = drives.fetch(index)
      volumes(drive).reverse_each do |volume|
        udisksctl(run, 'unmount', volume['path']) unless mount_points(volume).empty?
      end
      udisksctl(run, 'power-off', drive['path'])
      puts "Ejected #{drive_name(drive)} (#{drive['path']}). It is safe to remove."
      0
    rescue Interrupt
      puts 'Cancelled.'
      130
    rescue StandardError => error
      warn "Drive operation failed: #{error.message}"
      1
    end

    def removable_drives(run)
      result = run.call('lsblk', %w[-J --tree -o PATH,TYPE,HOTPLUG,RM,VENDOR,MODEL,SIZE,FSTYPE,LABEL,MOUNTPOINTS])
      check_result('lsblk', result)
      JSON.parse(result[:stdout]).fetch('blockdevices').select do |device|
        device['type'] == 'disk' && (device['hotplug'] || device['rm'])
      end
    end

    # The drive itself counts when it holds a filesystem without a partition table.
    def volumes(device)
      own = device['type'] == 'disk' && !device['fstype'] ? [] : [device]
      own + (device['children'] || []).flat_map { |child| volumes(child) }
    end

    def mount_points(volume)
      (volume['mountpoints'] || []).compact
    end

    def drive_name(drive)
      name = [drive['vendor'], drive['model']].compact.map(&:strip).reject(&:empty?).join(' ')
      name.empty? ? 'Drive' : name
    end

    def picker_label(drive)
      labels = volumes(drive).filter_map { |volume| volume['label'] }
      [drive_name(drive), drive['size'], drive['path'], labels.join(', ')].reject { |field| field.to_s.empty? }.join('  ')
    end

    def udisksctl(run, action, path)
      result = run.call('udisksctl', [action, '-b', path])
      check_result("udisksctl #{action} #{path}", result)
    end

    def check_result(label, result)
      raise "#{label}: #{result[:error].message}" if result[:error]
      raise "#{label} was terminated by #{result[:signal]}" if result[:signal]
      return if result[:status] == 0

      detail = Shared.single_line(result[:stderr])
      raise "#{label} exited with status #{result[:status]}#{detail.empty? ? '' : ": #{detail}"}"
    end

    def pick_drive(labels, input: $stdin, output: $stdout)
      raise 'Eject requires an interactive terminal.' unless input.tty? && output.tty?
      input.raw do
        output.write("\e[?1049h\e[?25l")
        WorkspaceProjects.pick_list('Choose drive to eject', labels, [], 0, input, output, multiple: false)&.first
      ensure
        output.write("\e[?25h\e[?1049l")
        output.flush
      end
    end
  end
end
