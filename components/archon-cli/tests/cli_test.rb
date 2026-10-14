require_relative 'test_helpers'

def run_cli(arguments)
  status, output, error = capture { Archon.main(arguments) }
  { status: status, stdout: output, stderr: error }
end

usage_cases = [%w[h extra], %w[p s], %w[l b], %w[libs graph], %w[w s], %w[wt s], [], ['unknown'], %w[help extra],
               ['visual-studio-code'], ['vsc'], ['workspace'], ['workspaces'], ['workspaces-herdr'], ['workspaces-tmux'], ['wh'],
               %w[workspaces start], %w[workspaces stop], %w[workspaces kill],
               %w[workspaces unknown], %w[workspaces help extra]]
%w[herdr tmux].each do |backend|
  usage_cases.concat([['workspaces', backend], ['workspaces', backend, 'launch'],
                      ['workspaces', backend, 'start', '--group', 'hubs'],
                      ['workspaces', backend, 'kill', 'extra'], ['workspaces', backend, 'kill', '-g', 'general'],
                      ['workspaces', backend, 'start', '--group']])
end
usage_cases.concat([%w[projects], %w[projects unknown], %w[projects global], %w[projects help unknown],
                    %w[projects help status extra]])
%w[delete prune remote status sync].each { |command| usage_cases << ['projects', command, '--invalid'] }
usage_cases.concat([%w[projects libs], %w[projects libs unknown], %w[projects libs status], %w[projects libs help unknown],
                    %w[projects libs help build extra], %w[projects libs build --invalid], %w[projects libs graph extra]])
usage_cases.each do |arguments|
  test("usage error: #{arguments.join(' ')}") do
    fixture do
      result = run_cli(arguments)
      equal 2, result[:status]
      assert !result[:stderr].empty?
      equal '', result[:stdout]
    end
  end
end

test('help, aliases, and nested command help work without external commands') do
  fixture do |fixture|
    %w[git gh bun tmux herdr].each do |name|
      write_executable(File.join(fixture[:bin], name), "#!/bin/sh\necho unexpected >> \"$HOME/unexpected-command\"\nexit 99\n")
    end
    [['d', 'drives', ['--help']], ['h', 'help', []], ['p', 'projects', %w[help status]], ['p', 'projects', %w[libs help build]],
     ['w', 'workspaces', ['--help']]].each do |short, full, options|
      result = run_cli([short, *options])
      equal 0, result[:status]
      equal result, run_cli([full, *options])
      assert result[:stdout].start_with?("Usage: archon #{full} ") if full.start_with?('workspace')
    end
    [[], ['projects'], %w[projects libs], ['workspaces']].each do |prefix|
      %w[-h --help].each { |help| equal 0, run_cli([*prefix, help])[:status] }
    end
    { 'h' => 'herdr', 't' => 'tmux', 'vsc' => 'visual-studio-code' }.each do |short, full|
      result = run_cli(['workspaces', full, '--help'])
      equal 0, result[:status]
      assert result[:stdout].start_with?("Usage: archon workspaces #{full} ")
      %w[help -h].each do |help|
        equal result, run_cli(['workspaces', full, help])
      end
      equal result, run_cli(['w', short, '--help'])
    end
    [['projects', %w[delete libs prune remote status sync help]], [%w[projects libs], %w[build graph help]]].each do |prefix, commands|
      commands.each do |command|
        result = run_cli([*prefix, 'help', command])
        equal 0, result[:status]
        assert result[:stdout].start_with?('Usage: archon ')
        equal result, run_cli([*prefix, command, '--help'])
      end
    end
    assert !File.exist?(File.join(fixture[:home], 'unexpected-command'))
  end
end

test('the executable preserves CLI output and exit codes for errors, help, and aliases') do
  fixture do
    [[], ['unknown'], %w[w h start --group invalid], %w[p libs status],
     ['--help'], %w[w t --help], %w[p libs help build], %w[p help status]].each do |arguments|
      result = run_archon(arguments)
      equal nil, result[:signal]
      equal run_cli(arguments), result.slice(:status, :stdout, :stderr)
    end
  end
end

[%w[projects status], %w[projects delete], %w[projects prune], %w[projects libs graph],
 %w[projects libs build]].each do |arguments|
  test("#{arguments.join(' ')} treats a missing root as empty") do
    fixture do |fixture|
      result = run_archon(arguments)
      equal 0, result[:status]
      assert result[:stdout].include?(arguments.last == 'prune' ? 'No obsolete' : 'No local Git repositories')
      assert !File.exist?(File.join(fixture[:home], 'projects'))
    end
  end
end

test('projects sync help has no filesystem effects and sync creates the root') do
  fixture do |fixture|
    equal 0, run_archon(%w[projects sync --help])[:status]
    assert !File.exist?(File.join(fixture[:home], 'projects'))
    fake_github(fixture)
    ENV['TEST_USER_REPOS'] = "1\ttest-user/new\tunused\tfalse\tpublic"
    write_executable(File.join(fixture[:bin], 'git'), "#!/bin/sh\n[ \"$1\" = clone ] || exit 99\nmkdir -p \"$3/.git\"\n")
    result = run_archon(%w[projects sync])
    equal 0, result[:status]
    assert result[:stdout].include?('cloned')
    assert File.directory?(File.join(fixture[:home], 'projects/personal/test-user/new/.git'))
  end
end

[[%w[projects status], [], 'Unexpected error:'],
 [%w[projects libs graph], ['mrzli-jslib'], 'Could not generate dependency graph:']].each do |arguments, relative_root, message|
  %w[file unreadable].each do |kind|
    test("#{arguments.join(' ')} rejects a #{kind} operation root") do
      fixture do |fixture|
        root = File.join(fixture[:home], 'projects/personal', *relative_root)
        FileUtils.mkdir_p(File.dirname(root))
        if kind == 'file'
          File.write(root, 'preserve')
        else
          FileUtils.mkdir_p(root)
          File.chmod(0, root)
        end
        begin
          result = run_archon(arguments)
          equal 1, result[:status]
          assert result[:stderr].include?(message), result[:stderr]
        ensure
          File.chmod(0o700, root) if kind == 'unreadable'
        end
      end
    end
  end
end

test('sequential command invocations keep distinct roots and refuse unsafe deletion roots') do
  fixture do |fixture|
    home = fixture[:home]
    %w[first second].each do |name|
      root = File.join(fixture[:root], name)
      FileUtils.mkdir_p(root)
      result, output, = capture { Archon::Projects.run_projects(['status'], home: home, root: root) }
      equal 0, result
      assert output.include?(root)
      result, _, error = capture { Archon::Projects.run_projects(%w[prune -n], home: home, root: root) }
      equal 1, result
      assert error.include?('Refusing to delete: unexpected operation root:')
    end
  end
end

test('Ctrl+C during a projects command exits with status 130 without a backtrace') do
  fixture do |fixture|
    marker = File.join(fixture[:root], 'gh-started')
    write_executable(File.join(fixture[:bin], 'gh'), "#!/bin/sh\ntouch #{Shellwords.escape(marker)}\nexec sleep 20\n")
    Open3.popen3(RbConfig.ruby, ARCHON, 'projects', 'remote', pgroup: true) do |input, output, error, child|
      input.close
      begin
        100.times do
          break if File.exist?(marker)
          sleep 0.01
        end
        assert File.exist?(marker)
        # A terminal delivers Ctrl+C to the whole foreground process group.
        Process.kill('INT', -child.pid)
        assert child.join(3), 'cancellation did not finish promptly'
        equal 130, child.value.exitstatus
        equal '', output.read
        stderr = error.read
        assert !stderr.include?('Interrupt') && !stderr.match?(/^\s+from /), stderr
      ensure
        if child.alive?
          Process.kill('KILL', -child.pid)
          child.join
        end
      end
    end
  end
end
