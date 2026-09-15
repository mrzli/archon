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
