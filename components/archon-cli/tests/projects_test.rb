require_relative 'test_helpers'

Projects = Archon::Projects

test('project inventory parses rows and rejects incomplete data') do
  repository = Projects.parse_repository("1\tOwner/Repo\tssh-url\ttrue\tprivate")
  equal({ id: '1', owner: 'Owner', name: 'Repo', name_with_owner: 'Owner/Repo', ssh_url: 'ssh-url', archived: true, visibility: 'private' }, repository)
  ['', "1\tOwner/Repo", "\tOwner/Repo\tssh\tfalse\tpublic", "1\tOwner/\tssh\tfalse\tpublic",
   "1\t/Repo\tssh\tfalse\tpublic", "1\tOwner/Repo\t\tfalse\tpublic", "1\tOwner/Repo\tssh\tyes\tpublic",
   "1\tOwner/Repo\tssh\tfalse\t"].each do |row|
    raises(/GitHub returned incomplete repository data:/) { Projects.parse_repository(row) }
  end
end

test('project inventory keys and exclusions are case insensitive') do
  repository = { owner: 'Owner', name_with_owner: 'Owner/Repo' }
  equal 'owner/repo', Projects.repository_key(repository)
  assert Projects.blacklisted?(repository, ['OWNER'], [])
  assert Projects.blacklisted?(repository, [], ['OWNER/REPO'])
  assert !Projects.blacklisted?(repository, [], [])
  equal ['Owner/Repo'], Projects.blacklist_lookup_names(['Owner/Repo', 'OWNER/REPO', 'invalid'])
end

test('blacklist validation accepts canonical owned repositories and aggregates policy errors') do
  owners, repositories = Projects.validate_blacklists('user', ['Org'], { 'user/repo' => 'User/Repo', 'org/repo' => 'Org/Repo' },
    organization_blacklist: ['ORG'], repository_blacklist: %w[user/repo org/repo])
  equal Set['org'], owners
  equal Set['user/repo', 'org/repo'], repositories
  begin
    Projects.validate_blacklists('user', ['Org'], { 'user/old' => 'user/new', 'outsider/repo' => 'outsider/repo' },
      organization_blacklist: ['invalid/name', 'Org', 'ORG', 'Missing'],
      repository_blacklist: ['invalid', 'user/absent', 'USER/ABSENT', 'user/old', 'outsider/repo'])
    raise 'validation accepted an invalid policy'
  rescue StandardError => error
    ['Invalid organization', 'Duplicate organization', 'not an active organization', 'Invalid repository',
     'does not exist or is not accessible', 'Duplicate repository', 'is now "user/new"', 'is not owned by'].each do |message|
      assert error.message.include?(message), error.message
    end
  end
end

test('projects list paginated filtered and deduplicated remotes') do
  fixture do |fixture|
    fake_github(fixture)
    ENV['TEST_USER_REPOS'] = "1\ttest-user/Zeta\tssh-zeta\tfalse\tpublic\n2\tAlphaOrg/Shared\tssh-shared\tfalse\tpublic"
    ENV['TEST_ORG_REPOS'] = "2\talphaorg/shared\tssh-shared\ttrue\tprivate\n3\tAlphaOrg/Alpha\tssh-alpha\tfalse\tpublic"
    result = run_archon(%w[projects remote])
    equal 0, result[:status]
    equal "AlphaOrg/Alpha\nalphaorg/shared (private, archived)\ntest-user/Zeta\n", result[:stdout]
    calls = File.read(File.join(fixture[:home], 'gh-calls'))
    ['user/memberships/orgs?', 'user/repos?', 'orgs/AlphaOrg/repos?'].each do |endpoint|
      assert calls.include?("--paginate #{endpoint}")
    end
    Projects::ORGANIZATION_BLACKLIST.each { |owner| assert !calls.include?("orgs/#{owner}/repos") }
    ENV['TEST_ORGS'] = ''
    equal 1, run_archon(%w[projects remote])[:status]
    ENV['TEST_USER'] = ''
    assert run_archon(%w[projects remote])[:stderr].include?('empty username')
  end
end

test('project discovery preserves depth, sorting, symlink exclusion, and dry run safety') do
  fixture do |fixture|
    root = File.join(fixture[:home], 'projects/personal')
    %w[Beta/repository alpha/second alpha/first alpha/not-a-repository/nested direct/.git/repository].each do |name|
      FileUtils.mkdir_p(File.join(root, name, '.git'))
    end
    File.symlink(File.join(root, 'alpha'), File.join(root, 'symlink-owner'))
    File.symlink(File.join(root, 'alpha/first'), File.join(root, 'alpha/symlink-repo'))
    result = run_archon(%w[projects delete --dry-run])
    equal 0, result[:status]
    equal %w[alpha/first alpha/second Beta/repository].map { |name| File.join(root, name) }, result[:stdout].lines.drop(1).map(&:strip)
    assert File.directory?(File.join(root, 'alpha/first/.git'))
  end
end

test('projects sync refuses an occupied clone destination and preserves its files') do
  fixture do |fixture|
    fake_github(fixture)
    ENV['TEST_ORG_REPOS'] = "1\tAlphaOrg/alpha\tunused\tfalse\tpublic"
    destination = File.join(fixture[:home], 'projects/personal/AlphaOrg/alpha')
    FileUtils.mkdir_p(destination)
    File.write(File.join(destination, 'keep'), 'safe')
    result = run_archon(%w[projects sync])
    equal 1, result[:status]
    assert result[:stdout].include?('ERROR: destination already exists and is not a repository:')
    equal 'safe', File.read(File.join(destination, 'keep'))
  end
end
