require_relative 'test_helpers'

test('admin validates arguments and shows help without service operations') do
  calls = []
  run = ->(*) { calls << :unexpected }
  [[], %w[voice], %w[unknown], %w[voice restart], %w[voice start extra],
   %w[voice stop --sudo], %w[help extra], %w[unknown --help]].each do |arguments|
    status, output, error = capture { Archon::Admin.run_admin(arguments, run: run) }
    equal 2, status
    equal '', output
    assert error.include?('Usage: archon admin')
  end
  [%w[help], %w[-h], %w[--help], %w[help voice], %w[voice help],
   %w[voice -h], %w[voice --help], %w[voice start -h], %w[voice start --help],
   %w[voice stop -h], %w[voice stop --help]].each do |arguments|
    status, output, error = capture { Archon::Admin.run_admin(arguments, run: run) }
    equal 0, status
    assert output.include?('Usage: archon admin')
    equal '', error
  end
  equal [], calls
end

test('admin and its alias start and stop only the Voxtype user service') do
  fixture do |fixture|
    write_executable(File.join(fixture[:bin], 'systemctl'), <<~'SH')
      #!/bin/sh
      printf '%s\n' "$*" >> "$HOME/service-calls"
    SH
    %w[start stop].each do |action|
      %w[admin a].each do |command|
        result = run_archon([command, 'voice', action])
        equal 0, result[:status]
        equal '', result[:stderr]
        assert result[:stdout].include?(action == 'start' ? 'started' : 'stopped')
      end
    end
    equal ['--user start voxtype.service'] * 2 + ['--user stop voxtype.service'] * 2,
          File.readlines(File.join(fixture[:home], 'service-calls'), chomp: true)
  end
end

test('admin reports service failures without claiming success') do
  [{ status: 5 }, { status: nil, signal: 'SIGTERM' }, { error: Errno::ENOENT.new('systemctl') }].each do |result|
    run = ->(*) { result }
    status, output, error = capture { Archon::Admin.run_admin(%w[voice start], run: run) }
    equal 1, status
    equal '', output
    assert error.include?('Voice operation failed:')
  end
  fixture do |fixture|
    write_executable(File.join(fixture[:bin], 'systemctl'), "#!/bin/sh\necho 'Service unavailable' >&2\nexit 5\n")
    result = run_archon(%w[a voice stop])
    equal 1, result[:status]
    equal '', result[:stdout]
    assert result[:stderr].include?('Service unavailable')
  end
end

test('battery commands validate arguments and provide help without operations') do
  run = ->(*) { raise 'unexpected operation' }
  [%w[battery], %w[battery conservation], %w[battery conservation yes],
   %w[battery status extra], %w[battery conservation on extra]].each do |arguments|
    status, = capture { Archon::Admin.run_admin(arguments, run: run, sys_root: '/nonexistent') }
    equal 2, status
  end
  [%w[help battery], %w[battery --help], %w[battery conservation --help],
   %w[battery status -h], %w[battery conservation on --help]].each do |arguments|
    status, output, error = capture { Archon::Admin.run_admin(arguments, run: run, sys_root: '/nonexistent') }
    equal 0, status
    assert output.include?('battery conservation')
    equal '', error
  end
end

def battery_fixture
  Dir.mktmpdir('archon-battery-') do |root|
    control = File.join(root, 'bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode')
    battery = File.join(root, 'class/power_supply/BAT0')
    FileUtils.mkdir_p(File.dirname(control))
    FileUtils.mkdir_p(battery)
    File.write(control, "0\n")
    File.write(File.join(battery, 'capacity'), "79\n")
    File.write(File.join(battery, 'status'), "Not charging\n")
    yield root, control
  end
end

test('battery status is read-only and conservation changes are verified and repeat-safe') do
  battery_fixture do |root, control|
    calls = []
    run = lambda do |command, arguments, stdio:|
      equal 'sudo', command
      equal :inherit, stdio
      equal ['sh', '-c', 'printf "%s\\n" "$1" > "$2"', 'archon-battery'], arguments.first(4)
      equal control, arguments.last
      calls << arguments[-2]
      # Execute the exact write with ordinary permissions against the fixture.
      Archon::Shared.run_process(arguments.first, arguments.drop(1))
    end
    %w[off on on off off].each do |setting|
      status, output, error = capture do
        Archon::Admin.run_admin(['battery', 'conservation', setting], run: run, sys_root: root)
      end
      equal 0, status
      equal "Battery conservation #{setting}.\n", output
      equal '', error
      status, output, error = capture do
        Archon::Admin.run_admin(%w[battery status], run: run, sys_root: root)
      end
      equal 0, status
      equal "Battery: 79% (Not charging)\nConservation: #{setting}\n", output
      equal '', error
    end
    equal %w[1 0], calls
  end
end

test('battery failures never claim success') do
  battery_fixture do |root, control|
    [{ status: 1 }, { signal: 'SIGTERM' }, { error: Errno::ENOENT.new('sudo') },
     { status: 0 }].each do |result|
      status, output, error = capture do
        Archon::Admin.run_admin(%w[battery conservation on], run: ->(*) { result }, sys_root: root)
      end
      equal 1, status
      equal '', output
      assert error.include?('Battery operation failed:')
      equal "0\n", File.read(control)
    end
    File.write(control, "unexpected\n")
    status, output, error = capture do
      Archon::Admin.run_admin(%w[battery status], sys_root: root)
    end
    equal 1, status
    equal '', output
    assert error.include?('Unexpected conservation setting')
    File.unlink(control)
    status, output, error = capture do
      Archon::Admin.run_admin(%w[battery conservation on], run: ->(*) { raise 'unexpected operation' }, sys_root: root)
    end
    equal 1, status
    equal '', output
    assert error.include?('unavailable on this machine')
  end
end
