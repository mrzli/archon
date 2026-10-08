require_relative 'workspace_helpers'

Projects = Archon::WorkspaceProjects

test('workspace list uses shared discovery and aliases without external commands or filesystem changes') do
  fixture do |fixture|
    equal 0, run_archon(%w[w list])[:status]
    assert !File.exist?(File.join(fixture[:home], 'projects'))
    paths = %w[cloned/one personal/owner/two].map { |relative| workspace_directory(fixture, relative) }
    expected = paths.map { |path| path.sub(fixture[:home], '~') }.join("\n") + "\n"
    result = run_archon(%w[workspaces list])
    equal expected, result[:stdout]
    equal 0, result[:status]
    equal result, run_archon(%w[w list])
    equal paths, Projects.discover_projects(fixture[:home])
    %w[help -h --help].each { |flag| equal 0, run_archon(['w', 'list', flag])[:status] }
    [%w[-g current], ['extra'], %w[--ai codex]].each { |options| equal 2, run_archon(['w', 'list', *options])[:status] }
    assert !File.exist?(File.join(ENV.fetch('XDG_STATE_HOME'), 'archon'))
  end
end

test('terminal backends share discovery and remember selections independently from VS Code') do
  fixture do |fixture|
    first = workspace_directory(fixture, 'cloned/one')
    second = workspace_directory(fixture)
    state_root = File.join(fixture[:root], 'custom-state')
    context = { home: fixture[:home], state_home: state_root }
    seen = []
    %w[tmux herdr].each_with_index do |backend, index|
      project = [first, second][index]
      picker = lambda do |paths, previous, home:|
        seen << [backend, paths, previous, home]
        { 'projects' => [project] }
      end
      equal [project], Archon::Workspaces.select_projects(backend, **context, picker: picker)
      state_path = File.join(state_root, 'archon/workspaces', "#{backend}.json")
      equal({ 'projects' => [project] }, Projects.load_selection(state_path))
      equal 0o600, File.stat(state_path).mode & 0o777
      equal 1, Dir.children(File.dirname(state_path)).count { |name| name == "#{backend}.json" }
    end
    equal %w[tmux herdr], seen.map(&:first)
    seen.each do |_, paths, previous, home|
      equal [first, second], paths
      equal({ 'projects' => [] }, previous)
      equal fixture[:home], home
    end
    assert !File.exist?(File.join(state_root, 'archon/workspaces/visual-studio-code.json'))
    restored = nil
    equal [], Archon::Workspaces.select_projects('tmux', **context, picker: ->(_, previous, **_) { restored = previous; { 'projects' => [] } })
    equal({ 'projects' => [first] }, restored)
    equal({ 'projects' => [] }, Projects.load_selection(File.join(state_root, 'archon/workspaces/tmux.json')))
  end
end

test('invalid state is reported without overwriting data or calling the picker') do
  fixture do |fixture|
    workspace_directory(fixture)
    path = File.join(ENV['XDG_STATE_HOME'], 'archon/workspaces/tmux.json')
    ['{broken', '[]', '{"projects":null}', '{"projects":[1]}'].each do |content|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
      equal 1, Archon::WorkspacesTmux.run_workspaces_tmux(['start'], home: fixture[:home], picker: ->(*_, **_) { raise 'must not pick' })
      equal content, File.read(path)
    end
    ['{"projects":[]}', '{"projects":[],"workspace":0}', '{"projects":[],"workspace":"1"}'].each do |content|
      File.write(path, content)
      raises(/Invalid saved selection/) { Projects.load_selection(path, workspace: true) }
    end
  end
end

test('VS Code remembers its workspace and selection in its own state file') do
  fixture do |fixture|
    project = workspace_directory(fixture)
    state_root = File.join(fixture[:root], 'state')
    picker = ->(paths, previous, home:, workspace:) {
      equal true, workspace
      equal [project], paths
      equal fixture[:home], home
      equal({ 'workspace' => 1, 'projects' => [] }, previous)
      { 'workspace' => 6, 'projects' => [] }
    }
    equal 0, Archon::VisualStudioCode.run_visual_studio_code(['start'], home: fixture[:home], state_home: state_root,
      picker: picker, launch: ->(*_, **_) { raise 'must not launch' })
    directory = File.join(state_root, 'archon/workspaces')
    equal({ 'workspace' => 6, 'projects' => [] }, Projects.load_selection(File.join(directory, 'visual-studio-code.json'), workspace: true))
    equal ['visual-studio-code.json'], Dir.children(directory)
    assert !File.exist?(File.join(fixture[:home], '.local/state/archon/workspaces'))
  end
end

test('the Claude tab command continues only when the project has a saved conversation') do
  fixture do |fixture|
    project = File.join(fixture[:root], 'my.project dir')
    FileUtils.mkdir_p(project)
    write_executable(File.join(fixture[:bin], 'claude'), "#!/bin/sh\nprintf 'claude %s\\n' \"$*\"\n")
    run = -> { Open3.capture2('bash', '-c', Archon::Workspaces::CLAUDE_COMMAND, chdir: project).first }
    equal "claude \n", run.call
    # Claude names project folders after the path with every non-alphanumeric character replaced by '-'.
    conversations = File.join(fixture[:home], '.claude/projects', project.gsub(/[^[:alnum:]]/, '-'))
    FileUtils.mkdir_p(conversations)
    File.write(File.join(conversations, 'session.jsonl'), "{}\n")
    equal "claude --continue\n", run.call
  end
end

test('a client reattaches only after a restart that began while it was attached has finished') do
  fixture do |fixture|
    marker = File.join(fixture[:root], 'restart.json')
    since = Time.now.to_f
    equal false, Archon::Workspaces.wait_for_restart(marker, since: since)
    Archon::Workspaces.mark_restart(marker, started_at: since - 1, finished: true)
    equal false, Archon::Workspaces.wait_for_restart(marker, since: since)
    Archon::Workspaces.mark_restart(marker, started_at: since + 1, finished: true)
    equal true, Archon::Workspaces.wait_for_restart(marker, since: since)
    # An unfinished restart whose process is gone counts as finished; a live one is waited for.
    File.write(marker, JSON.generate(pid: 2**22 + 12_345, started_at: since + 1, finished: false))
    equal true, Archon::Workspaces.wait_for_restart(marker, since: since)
    Archon::Workspaces.mark_restart(marker, started_at: since + 1, finished: false)
    equal false, Archon::Workspaces.wait_for_restart(marker, since: since, timeout: 0.2)
    File.write(marker, '{broken')
    equal false, Archon::Workspaces.wait_for_restart(marker, since: since)
  end
end
