require_relative 'test_helpers'

Shared = Archon::Shared

test('status reports changes, stashes, unpushed commits, inspection errors, and fetch warnings') do
  fixture do |fixture|
    root = File.join(fixture[:home], 'projects/personal/owner')
    changed = initialize_repository(File.join(root, 'changed'))[:path]
    clean = initialize_repository(File.join(root, 'clean'))[:path]
    File.write(File.join(changed, 'tracked.txt'), "stashed\n", mode: 'a')
    git(changed, 'stash', 'push', '-qm', 'test-stash')
    File.write(File.join(changed, 'tracked.txt'), "unstaged\n", mode: 'a')
    File.write(File.join(changed, 'staged.txt'), 'staged')
    File.write(File.join(changed, 'untracked.txt'), 'untracked')
    git(changed, 'add', 'staged.txt')
    FileUtils.mkdir_p(File.join(root, 'broken'))
    File.write(File.join(root, 'broken/.git'), 'broken')
    git(clean, 'remote', 'add', 'origin', File.join(fixture[:root], 'missing'))
    result = run_archon(%w[projects status])
    equal 1, result[:status]
    assert result[:stdout].include?('staged: 1, unstaged: 1, untracked: 1')
    assert result[:stdout].include?('stash: 1')
    assert result[:stdout].include?('main=1 (no upstream)')
    assert result[:stdout].match?(/broken +ERROR:/)
    result = run_archon(%w[projects status --fetch])
    equal 1, result[:status]
    assert result[:stdout].include?('warnings: fetch failed:')
  end
end

test('rename paths do not inflate working tree counts and detached HEAD has a useful label') do
  fixture do |fixture|
    repository = initialize_repository(File.join(fixture[:root], 'repo'))
    git(repository[:path], 'mv', 'tracked.txt', 'renamed.txt')
    equal({ staged: 1, unstaged: 0, untracked: 0 }, Shared.working_tree_changes(repository))
    git(repository[:path], 'commit', '-qm', 'rename')
    git(repository[:path], 'checkout', '--detach')
    status = Shared.inspect_repositories([repository], false, ->(repo) { repo[:name] }).first
    assert status[:branch].start_with?('detached@')
  end
end

test('deletion treats commits only on a detached HEAD or tags and ignored files as unclean') do
  fixture do |fixture|
    remote = File.join(fixture[:root], 'remote.git')
    Open3.capture3('git', 'init', '-q', '--bare', remote)
    repository = initialize_repository(File.join(fixture[:root], 'repo'))
    path = repository[:path]
    git(path, 'remote', 'add', 'origin', remote)
    git(path, 'push', '-qu', 'origin', 'main')
    File.write(File.join(path, '.gitignore'), "node_modules/\n.env\n")
    git(path, 'add', '.gitignore')
    git(path, 'commit', '-qm', 'ignore')
    git(path, 'push', '-q')
    git(path, 'tag', 'pushed-commit')
    FileUtils.mkdir_p(File.join(path, 'node_modules/package'))
    File.write(File.join(path, 'node_modules/package/index.js'), 'generated')
    inspect = -> { Shared.inspect_repositories([repository], false, ->(repo) { repo[:name] }).first }
    assert !Shared.unclean?(inspect.call), 'pushed commits, tags and ignored directories are clean'

    git(path, 'checkout', '-q', '--detach')
    git(path, 'commit', '-q', '--allow-empty', '-m', 'detached work')
    status = inspect.call
    assert Shared.unclean?(status)
    equal ['detached HEAD or tags=1 (not on any branch or remote)'], status[:ahead]

    git(path, 'tag', 'local-only')
    git(path, 'checkout', '-q', 'main')
    status = inspect.call
    assert Shared.unclean?(status)
    equal ['tags=1 (not on any branch or remote)'], status[:ahead]
    git(path, 'tag', '-d', 'local-only')

    File.write(File.join(path, '.env'), 'SECRET=1')
    status = inspect.call
    equal 1, status[:ignored_files]
    assert Shared.unclean?(status)
    output = StringIO.new
    Shared.print_unclean_reasons([status], output)
    assert output.string.include?('ignored files: 1'), output.string
  end
end

test('sync plans sort clone and update operations and continue after failures') do
  get_name = ->(repo) { repo[:name] }
  operations = []
  status, output, = capture do
    Shared.sync_repositories(remote: -> { [{ name: 'alpha' }, { name: 'beta' }, { name: 'gamma' }] },
      local: -> { [{ name: 'beta' }] }, key: get_name, get_name: get_name, sort_key: get_name,
      update: ->(repo, _) { operations << "update #{repo[:name]}"; raise 'injected update failure' },
      clone: ->(repo) { operations << "clone #{repo[:name]}"; { succeeded: true, message: 'cloned' } })
  end
  equal 1, status
  equal ['clone alpha', 'update beta', 'clone gamma'], operations
  assert output.include?('ERROR: injected update failure')
  assert output.include?('[3/3]')
end

test('sync fetches and fast-forwards while refusing dirty, detached, diverged, and untracked branches') do
  fixture do |fixture|
    remote = File.join(fixture[:root], 'remote.git')
    seed = initialize_repository(File.join(fixture[:root], 'seed'))[:path]
    git(fixture[:root], 'init', '--bare', remote)
    git(seed, 'remote', 'add', 'origin', remote)
    git(seed, 'push', '-u', 'origin', 'main')
    local = File.join(fixture[:root], 'local')
    git(fixture[:root], 'clone', '--branch', 'main', remote, local)
    repository = { name: 'local', path: local }
    get_name = ->(repo) { repo[:name] }
    update = -> { Shared.update_repository(repository, get_name) }
    assert update.call[:message].include?('up to date')
    File.write(File.join(seed, 'remote.txt'), 'new')
    git(seed, 'add', '.')
    git(seed, 'commit', '-qm', 'update')
    git(seed, 'push')
    assert update.call[:message].end_with?('updated')
    File.write(File.join(local, 'untracked'), 'preserve')
    assert update.call[:message].include?('working tree is not clean')
    File.unlink(File.join(local, 'untracked'))
    git(local, 'checkout', '--detach')
    assert update.call[:message].include?('detached HEAD')
    git(local, 'checkout', '-b', 'no-upstream')
    assert update.call[:message].include?('no-upstream has no upstream')
    git(local, 'checkout', 'main')
    File.write(File.join(local, 'local.txt'), 'local')
    git(local, 'add', '.')
    git(local, 'commit', '-qm', 'local change')
    File.write(File.join(seed, 'remote.txt'), 'another')
    git(seed, 'commit', '-qam', 'remote change')
    git(seed, 'push')
    assert !update.call[:succeeded]
    equal 'local', File.read(File.join(local, 'local.txt'))
  end
end

test('prune excludes blacklisted projects and refuses restoration or failed revalidation') do
  fixture do |fixture|
    root = File.join(fixture[:home], 'projects/personal')
    repository = initialize_repository(File.join(root, 'owner/obsolete'))
    FileUtils.mkdir_p(File.join(root, 'mrzli-other/keep/.git'))
    equal [repository[:path]], Archon::Projects.prunable_repositories([], root).map { |repo| repo[:path] }
    [:restored, :failed, :unchanged, :cancelled].each do |scenario|
      calls = []
      removed = []
      result, _, error = capture do
        Shared.destructive_workflow('prune', dry_run: false, root: root, required_root: root,
          local: -> { [repository] }, remote: ->(refresh) {
            calls << refresh
            raise 'inventory unavailable' if refresh && scenario == :failed
            refresh && scenario == :restored ? [repository] : []
          }, prunable: ->(_) { [repository] }, key: ->(repo) { repo[:name] }, get_name: ->(repo) { repo[:name] },
          empty_message: 'empty', confirm: ->(_) { scenario != :cancelled }, remove: ->(repos) { removed.concat(repos); 0 })
      end
      equal scenario == :unchanged ? 0 : 1, result
      equal scenario == :cancelled ? [false] : [false, true], calls
      equal scenario == :unchanged ? [repository] : [], removed
      assert error.include?('Nothing was deleted.') if %i[restored failed].include?(scenario)
    end
  end
end

test('deletion stops when a clean repository gains local work during confirmation') do
  fixture do |fixture|
    root = File.join(fixture[:home], 'projects/personal')
    clean = initialize_repository(File.join(root, 'owner/clean'))
    remote = File.join(fixture[:root], 'clean.git')
    Open3.capture3('git', 'init', '-q', '--bare', remote)
    git(clean[:path], 'remote', 'add', 'origin', remote)
    git(clean[:path], 'push', '-qu', 'origin', 'main')
    dirty = initialize_repository(File.join(root, 'owner/dirty'))
    File.write(File.join(dirty[:path], 'untracked.txt'), 'shown before confirmation')
    [[true, 1, []], [false, 0, [clean, dirty]]].each do |edit_during_prompt, expected, expected_removed|
      removed = []
      result, _, error = capture do
        Shared.destructive_workflow('delete', dry_run: false, root: root, required_root: root,
          local: -> { [clean, dirty] }, remote: ->(_) { [] }, prunable: ->(_) { [] }, key: ->(repo) { repo[:name] },
          get_name: ->(repo) { repo[:name] }, empty_message: 'empty',
          confirm: lambda { |statuses|
            equal ['dirty'], statuses.map { |status| status[:name] }
            File.write(File.join(clean[:path], 'new-work.txt'), 'written while the prompt was open') if edit_during_prompt
            true
          }, remove: ->(repos) { removed.concat(repos); 0 })
      end
      equal expected, result
      equal expected_removed, removed
      if edit_during_prompt
        assert error.include?('changed during confirmation: clean'), error
        assert error.include?('Nothing was deleted.')
        File.delete(File.join(clean[:path], 'new-work.txt'))
      end
    end
  end
end

test('confirmation requires terminal input and exact confirmation, including a second prompt for unclean repos') do
  unclean = { name: 'repo', branch: 'main', changes: { staged: 1, unstaged: 0, untracked: 0 },
              stash_count: 1, ahead: ['main=1'], ignored_files: 0, warnings: [] }
  [[[], "delete\n", true, 1], [[unclean], "delete\ndelete\n", true, 2],
   [[unclean], "delete\nno\n", false, 2], [[], "delete \n", false, 1], [[], '', false, 1]].each do |statuses, answers, expected, prompts|
    input, output, error = StringIO.new(answers), StringIO.new, StringIO.new
    input.define_singleton_method(:tty?) { true }
    output.define_singleton_method(:tty?) { true }
    equal expected, Shared.confirm_deletion(statuses, input: input, output: output, error: error)
    equal prompts, output.string.scan('Type "delete"').length
    assert output.string.include?('Unclean repositories:') if prompts == 2
  end
  error = StringIO.new
  assert !Shared.confirm_deletion([], input: StringIO.new('delete'), output: StringIO.new, error: error)
  assert error.string.include?('requires an interactive terminal')
end

test('delete refuses piped confirmation, dry run is harmless, and removal continues after failure') do
  fixture do |fixture|
    repository = initialize_repository(File.join(fixture[:home], 'projects/personal/owner/repo'))
    equal 0, run_archon(%w[projects delete -n])[:status]
    result = run_archon(%w[projects delete])
    equal 1, result[:status]
    assert File.directory?(repository[:path])
    assert result[:stderr].include?('requires an interactive terminal')
    paths = []
    result, output, error = capture do
      Shared.remove_repositories([{ path: '/fixture/first' }, { path: '/fixture/second' }], remove: ->(path) {
        paths << path
        raise 'injected failure' if path.end_with?('first')
      })
    end
    equal 1, result
    equal ['/fixture/first', '/fixture/second'], paths
    assert output.include?('Deleted /fixture/second')
    assert error.include?('Failed to delete 1 of 2 repositories.')
  end
end
