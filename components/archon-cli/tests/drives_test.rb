require_relative 'workspace_helpers'

def drive_devices
  [
    { 'path' => '/dev/nvme0n1', 'type' => 'disk', 'hotplug' => false, 'rm' => false, 'vendor' => nil,
      'model' => 'Internal', 'size' => '953.9G', 'fstype' => nil, 'label' => nil, 'mountpoints' => [],
      'children' => [{ 'path' => '/dev/nvme0n1p1', 'type' => 'part', 'fstype' => 'vfat', 'label' => nil,
                       'mountpoints' => ['/boot'] }] },
    { 'path' => '/dev/sdb', 'type' => 'disk', 'hotplug' => true, 'rm' => true, 'vendor' => 'SanDisk ',
      'model' => 'Ultra', 'size' => '57.3G', 'fstype' => nil, 'label' => nil, 'mountpoints' => [nil],
      'children' => [
        { 'path' => '/dev/sdb1', 'type' => 'part', 'fstype' => 'exfat', 'label' => 'BACKUP',
          'mountpoints' => ['/run/media/user/BACKUP'] },
        { 'path' => '/dev/sdb2', 'type' => 'part', 'fstype' => 'ext4', 'label' => 'DATA', 'mountpoints' => [nil] }
      ] },
    { 'path' => '/dev/sdc', 'type' => 'disk', 'hotplug' => true, 'rm' => false, 'vendor' => nil, 'model' => nil,
      'size' => '14.9G', 'fstype' => 'vfat', 'label' => 'PHOTOS', 'mountpoints' => ['/run/media/user/PHOTOS'] }
  ]
end

def drive_run(calls, devices: drive_devices, failures: {})
  lambda do |command, arguments, **|
    calls << [command, *arguments]
    next { stdout: JSON.generate('blockdevices' => devices), stderr: '', status: 0 } if command == 'lsblk'
    failures.fetch([command, *arguments], { stdout: '', stderr: '', status: 0 })
  end
end

test('drives validates arguments and shows help without device operations') do
  run = ->(*) { raise 'unexpected operation' }
  [[], %w[unknown], %w[list extra], %w[eject sdb], %w[help unknown], %w[list --all]].each do |arguments|
    status, output, error = capture { Archon::Drives.run_drives(arguments, run: run) }
    equal 2, status
    equal '', output
    assert error.include?('Usage: archon drives')
  end
  [%w[help], %w[-h], %w[--help], %w[help eject], %w[list -h], %w[eject --help]].each do |arguments|
    status, output, error = capture { Archon::Drives.run_drives(arguments, run: run) }
    equal 0, status
    assert output.start_with?('Usage: archon drives')
    equal '', error
  end
end

test('drives list shows only removable drives with partitions and mount state') do
  calls = []
  status, output, error = capture { Archon::Drives.run_drives(%w[list], run: drive_run(calls)) }
  equal 0, status
  equal '', error
  equal <<~TEXT, output
    SanDisk Ultra  57.3G  /dev/sdb
      /dev/sdb1  BACKUP  exfat  /run/media/user/BACKUP
      /dev/sdb2  DATA  ext4  not mounted

    Drive  14.9G  /dev/sdc
      /dev/sdc  PHOTOS  vfat  /run/media/user/PHOTOS
  TEXT
  equal 1, calls.length
end

test('drives report an empty state without picking or ejecting') do
  %w[list eject].each do |command|
    calls = []
    picker = ->(*) { raise 'unexpected picker' }
    status, output, = capture do
      Archon::Drives.run_drives([command], run: drive_run(calls, devices: [drive_devices.first]), picker: picker)
    end
    equal 0, status
    equal "No removable drives.\n", output
    equal 1, calls.length
  end
end

test('drives eject unmounts mounted filesystems of the chosen drive and powers it off') do
  calls = []
  offered = nil
  picker = ->(labels) { offered = labels; 0 }
  status, output, error = capture { Archon::Drives.run_drives(%w[eject], run: drive_run(calls), picker: picker) }
  equal 0, status
  equal '', error
  equal ['SanDisk Ultra  57.3G  /dev/sdb  BACKUP, DATA', 'Drive  14.9G  /dev/sdc  PHOTOS'], offered
  equal [%w[udisksctl unmount -b /dev/sdb1], %w[udisksctl power-off -b /dev/sdb]], calls.drop(1)
  equal "Ejected SanDisk Ultra (/dev/sdb). It is safe to remove.\n", output

  calls.clear
  capture { Archon::Drives.run_drives(%w[eject], run: drive_run(calls), picker: ->(_) { 1 }) }
  equal [%w[udisksctl unmount -b /dev/sdc], %w[udisksctl power-off -b /dev/sdc]], calls.drop(1)
end

test('drives eject cancels without device operations') do
  calls = []
  status, output, = capture { Archon::Drives.run_drives(%w[eject], run: drive_run(calls), picker: ->(_) { nil }) }
  equal 0, status
  equal "Cancelled.\n", output
  equal 1, calls.length
end

test('drives eject stops before power-off when an unmount fails') do
  calls = []
  busy = { %w[udisksctl unmount -b /dev/sdb1] => { stdout: '', stderr: "Error unmounting: target is busy\n", status: 1 } }
  status, output, error = capture do
    Archon::Drives.run_drives(%w[eject], run: drive_run(calls, failures: busy), picker: ->(_) { 0 })
  end
  equal 1, status
  equal '', output
  equal "Drive operation failed: udisksctl unmount /dev/sdb1 exited with status 1: Error unmounting: target is busy\n", error
  equal [%w[udisksctl unmount -b /dev/sdb1]], calls.drop(1)
end

test('drives eject chooses a drive in the terminal picker') do
  fixture do |fixture|
    File.write(File.join(fixture[:root], 'devices.json'), JSON.generate('blockdevices' => drive_devices))
    write_executable(File.join(fixture[:bin], 'lsblk'), "#!/bin/sh\ncat \"$HOME/../devices.json\"\n")
    write_executable(File.join(fixture[:bin], 'udisksctl'), "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$HOME/udisks-calls\"\n")
    status, transcript = workspace_terminal(%w[d eject]) do |terminal, wait|
      wait.call('Choose drive to eject')
      wait.call('1-2: choose')
      terminal.write('9')
      terminal.write('2')
      terminal.write("\r")
      wait.call('safe to remove')
    end
    equal 0, status
    assert transcript.include?('Ejected Drive (/dev/sdc).')
    equal ['unmount -b /dev/sdc', 'power-off -b /dev/sdc'],
          File.readlines(File.join(fixture[:home], 'udisks-calls'), chomp: true)
  end
end
