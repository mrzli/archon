require_relative 'test_helpers'

usage_cases = [%w[h extra], %w[p s], %w[l b], %w[w s], %w[wt s], [], ['unknown'], %w[help extra],
               ['workspace'], ['workspaces'], ['workspaces-herdr'], ['wh'],
               ['workspaces-tmux'], %w[workspaces-tmux launch], %w[workspaces-tmux start --group hubs],
               %w[workspaces-tmux kill extra], %w[workspaces-tmux kill -g general], %w[workspaces-tmux start --group]]
%w[projects libs].each do |domain|
  usage_cases.concat([[domain], [domain, 'unknown'], [domain, 'global'], [domain, 'help', 'unknown'], [domain, 'help', 'status', 'extra']])
  commands = %w[delete prune remote status sync] + (domain == 'libs' ? %w[build graph] : [])
  commands.each { |command| usage_cases << [domain, command, '--invalid'] }
end
usage_cases.each do |arguments|
  test("usage error: #{arguments.join(' ')}") do
    fixture do
      result = run_archon(arguments)
      equal 2, result[:status]
      equal nil, result[:signal]
      assert !result[:stderr].empty?
    end
  end
end

test('help, aliases, and nested command help work without external commands') do
  fixture do |fixture|
    %w[git gh bun tmux herdr].each { |name| write_executable(File.join(fixture[:bin], name), "#!/bin/sh\nexit 99\n") }
    [['h', 'help', []], ['l', 'libs', %w[help build]], ['p', 'projects', %w[help status]], ['w', 'workspaces', ['--help']], ['wt', 'workspaces-tmux', ['--help']]].each do |short, full, options|
      result = run_archon([short, *options])
      equal 0, result[:status]
      equal result, run_archon([full, *options])
      assert result[:stdout].start_with?("Usage: archon #{full} ") if full.start_with?('workspace')
    end
    [[], ['projects'], ['libs'], ['workspaces'], ['workspaces-tmux']].each do |prefix|
      %w[-h --help].each { |help| equal 0, run_archon([*prefix, help])[:status] }
    end
    %w[projects libs].each do |domain|
      commands = %w[delete prune remote status sync help] + (domain == 'libs' ? %w[build graph] : [])
      commands.each do |command|
        equal run_archon([domain, 'help', command]), run_archon([domain, command, '--help'])
      end
    end
  end
end

%w[projects libs].each do |domain|
  commands = %w[status delete prune] + (domain == 'libs' ? %w[graph build] : [])
  commands.each do |command|
    test("#{domain} #{command} treats a missing root as empty") do
      fixture do |fixture|
        result = run_archon([domain, command])
        equal 0, result[:status]
        assert result[:stdout].include?(command == 'prune' ? 'No obsolete' : 'No local Git repositories')
        assert !File.exist?(File.join(fixture[:home], 'projects'))
      end
    end
  end
  test("#{domain} sync help has no filesystem effects and sync creates the root") do
    fixture do |fixture|
      equal 0, run_archon([domain, 'sync', '--help'])[:status]
      assert !File.exist?(File.join(fixture[:home], 'projects'))
      fake_github(fixture)
      if domain == 'libs'
        ENV['TEST_LIB_REPOS'] = JSON.generate([{ name: 'new', nameWithOwner: 'mrzli-jslib/new' }])
        destination = File.join(fixture[:home], 'projects/personal/mrzli-jslib/new')
      else
        ENV['TEST_USER_REPOS'] = "1\ttest-user/new\tunused\tfalse\tpublic"
        write_executable(File.join(fixture[:bin], 'git'), "#!/bin/sh\n[ \"$1\" = clone ] || exit 99\nmkdir -p \"$3/.git\"\n")
        destination = File.join(fixture[:home], 'projects/personal/test-user/new')
      end
      result = run_archon([domain, 'sync'])
      equal 0, result[:status]
      assert result[:stdout].include?('cloned')
      assert File.directory?(File.join(destination, '.git'))
    end
  end
  %w[file unreadable].each do |kind|
    test("#{domain} rejects a #{kind} operation root") do
      fixture do |fixture|
        root = File.join(fixture[:home], 'projects/personal', *(domain == 'libs' ? ['mrzli-jslib'] : []))
        FileUtils.mkdir_p(File.dirname(root))
        if kind == 'file'
          File.write(root, 'preserve')
        else
          FileUtils.mkdir_p(root)
          File.chmod(0, root)
        end
        begin
          result = run_archon([domain, 'status'])
          equal 1, result[:status]
          assert result[:stderr].include?('Unexpected error:')
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
      result, output, = capture { Archon::Libraries.run_libraries(['status'], home: home, root: root) }
      equal 0, result
      assert output.include?(root)
      result, _, error = capture { Archon::Libraries.run_libraries(%w[delete -n], home: home, root: root) }
      equal 1, result
      assert error.include?('Refusing to delete: unexpected operation root:')
      result, _, error = capture { Archon::Projects.run_projects(%w[prune -n], home: home, root: root) }
      equal 1, result
      assert error.include?('Refusing to delete: unexpected operation root:')
    end
  end
end
