require_relative 'test_helpers'

test('workspace listing groups configured paths and marks missing directories') do
  fixture do |fixture|
    home = fixture[:home]
    FileUtils.mkdir_p(File.join(home, 'projects/personal/mrzli/flashcards-fe'))
    FileUtils.mkdir_p(File.join(home, 'projects/personal/mrzli/archon'))
    %w[zeta/.git alpha/.git .hidden/.git ignored/nested/.git].each do |path|
      FileUtils.mkdir_p(File.join(home, 'projects/personal/mrzli-jslib', path))
    end
    status, output, error = capture { Archon::Workspaces.run_workspaces(['list'], home: home) }
    equal 0, status
    equal '', error
    equal %w[general: flashcards: jslibs: misc:], output.lines(chomp: true).reject { |line| line.start_with?(' ') }
    assert output.include?("general:\n  ~/projects\n")
    assert output.include?("flashcards:\n  ~/projects/personal/mrzli/flashcards-fe\n  ~/projects/personal/mrzli/flashcards-be (missing)\n")
    assert output.include?("jslibs:\n  ~/projects/personal/mrzli-jslib/alpha\n  ~/projects/personal/mrzli-jslib/zeta\n")
    assert output.include?("  ~/projects/personal/mrzli/archon\n")
    assert output.include?('  ~/projects/personal/mrzli/docs (missing)')
    assert !output.include?('.hidden') && !output.include?('ignored')
    assert !output.include?(home)
  end
end

test('workspace listing supports group selection and empty groups without filesystem changes') do
  fixture do |fixture|
    %w[-g --group].each do |flag|
      status, output, error = capture do
        Archon::Workspaces.run_workspaces(['list', flag, 'jslibs'], home: fixture[:home])
      end
      equal 0, status
      equal "jslibs:\n  (no projects found)\n", output
      equal '', error
    end
    status, output, = capture { Archon::Workspaces.run_workspaces(['list'], home: fixture[:home]) }
    equal 0, status
    assert output.include?('~/projects (missing)')
    assert !File.exist?(File.join(fixture[:home], 'projects'))
  end
end

test('workspace list and help work through executable aliases without external commands') do
  fixture do |fixture|
    %w[git gh bun tmux herdr].each do |name|
      write_executable(File.join(fixture[:bin], name), "#!/bin/sh\necho unexpected >> \"$HOME/unexpected-command\"\nexit 99\n")
    end
    result = run_archon(%w[workspaces list -g flashcards])
    equal 0, result[:status]
    equal '', result[:stderr]
    assert result[:stdout].include?('flashcards-fe (missing)')
    equal result, run_archon(%w[w list --group flashcards])
    %w[help -h --help].each do |help|
      result = run_archon(['w', 'list', help])
      equal 0, result[:status]
      assert result[:stdout].start_with?('Usage: archon workspaces list ')
    end
    assert !File.exist?(File.join(fixture[:home], 'unexpected-command'))
    assert !File.exist?(File.join(fixture[:home], 'projects'))
  end
end

test('workspace listing rejects invalid groups, operands, and lifecycle options') do
  fixture do
    [%w[-g], %w[-g unknown], %w[--ai claude], %w[extra], %w[--help extra],
     %w[-g general -g flashcards]].each do |options|
      result = run_archon(['workspaces', 'list', *options])
      equal 2, result[:status]
      equal '', result[:stdout]
      assert result[:stderr].include?('Usage: archon workspaces list ')
    end
  end
end

test('misc is available for listing and both backends reject its previous group name') do
  fixture do
    equal 0, run_archon(%w[w list -g misc])[:status]
    equal 2, run_archon(%w[w list -g misc-projects])[:status]
    equal 'misc', Archon::Workspaces.parse_arguments(%w[start -g misc], help: Archon::Workspaces::ACTION_HELP)[:group]
    %w[herdr tmux].each do |backend|
      equal 2, run_archon(['w', backend, 'start', '-g', 'misc-projects'])[:status]
    end
  end
end
