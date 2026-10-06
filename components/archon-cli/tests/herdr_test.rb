require_relative 'workspace_helpers'

Herdr = Archon::WorkspacesHerdr

def herdr_fixture
  fixture do |fixture|
    path = File.join(fixture[:root], 'herdr-state.json')
    File.write(path, JSON.generate(running: false, workspaces: [], calls: [], next_id: 0, attachments: 0))
    ENV['HERDR_TEST_STATE'] = path
    yield fixture, path
  end
end

def herdr_state(path)
  JSON.parse(File.read(path))
end

def update_herdr_state(path)
  state = herdr_state(path)
  yield state
  File.write(path, JSON.generate(state))
end

def seed_herdr_workspaces(path, labels)
  update_herdr_state(path) do |state|
    state['running'] = true
    state['next_id'] = labels.length
    state['workspaces'] = labels.each_with_index.map do |label, index|
      { 'workspace_id' => "w#{(index + 1) * 7}", 'label' => label, 'tabs' => [] }
    end
  end
end

test('every failed Herdr creation step rolls back only its newly returned workspace ID') do
  definition = { session: 'example', directory: '/fixture/project', label: 'project' }
  created = { 'workspace' => { 'workspace_id' => 'w401', 'label' => 'example' },
              'tab' => { 'tab_id' => 'w401:t709' }, 'root_pane' => { 'pane_id' => 'w401:p901' } }
  operations = []
  request = ->(arguments) { operations << arguments; created }
  tabs = Archon::Workspaces.editor_tabs
  equal 0, Herdr.create_workspace(definition, tabs, request)[:status]
  operations.each_index do |failed_index|
    calls = []
    request = lambda do |arguments|
      calls << arguments
      raise 'injected failure' if calls.length == failed_index + 1
      created
    end
    result = Herdr.create_workspace(definition, tabs, request)
    equal 1, result[:status]
    equal failed_index.zero? ? nil : 0, result[:cleanup_status]
    expected = operations.take(failed_index + 1)
    expected += [%w[workspace close w401]] unless failed_index.zero?
    equal expected, calls
  end
  request = ->(arguments) { raise 'injected failure' unless arguments.first(2) == %w[workspace create]; created }
  equal 1, Herdr.create_workspace(definition, tabs, request)[:cleanup_status]
end

test('Herdr JSON capture separates successful stdout from diagnostic stderr') do
  herdr_fixture do |fixture, _|
    write_executable(File.join(fixture[:bin], 'herdr'), <<~'SH')
      #!/bin/sh
      echo 'configuration diagnostic' >&2
      printf '%s\n' '{"sessions":[]}'
    SH
    equal 0, Herdr.run_workspaces_herdr(['stop'], environment: {})
  end
end

test('Herdr existing tool recovery only submits commands to a single idle shell pane') do
  [
    ['codex', 1, nil, 100, 'bash', 'codex resume --last'],
    ['claude', 1, nil, 100, 'bash', Archon::Workspaces::CLAUDE_COMMAND],
    ['nvim', 1, nil, 100, 'bash', 'nvim .'],
    ['codex', 1, nil, 200, 'bash', nil],
    ['codex', 1, 'codex', 100, 'bash', nil],
    ['shell', 1, nil, 100, 'bash', nil],
    ['codex', 2, nil, 100, 'bash', nil],
    ['nvim', 1, nil, 100, 'nvim', nil],
    ['codex', 1, nil, 100, 'zsh', nil]
  ].each do |label, count, agent, foreground, process_name, expected|
    submitted = []
    request = lambda do |args|
      case args.first(2)
      when %w[tab list] then { 'tabs' => [{ 'tab_id' => 't1', 'label' => label, 'pane_count' => count }] }
      when %w[pane list] then { 'panes' => [{ 'tab_id' => 't1', 'pane_id' => 'p1', 'agent' => agent }] }
      when %w[pane process-info]
        assert !agent, 'native restore must not require a live shell'
        { 'process_info' => { 'shell_pid' => 100, 'foreground_process_group_id' => foreground,
                              'foreground_processes' => [{ 'pid' => 100, 'name' => process_name }] } }
      when %w[pane run] then submitted << args.last
      else raise "Unexpected command: #{args.inspect}"
      end
    end
    equal({ status: 0 }, Herdr.start_existing_tools('w1', request))
    equal Array(expected), submitted
  end
end

test('Herdr creates selected uniform workspaces, repeats safely and attaches only outside Herdr') do
  herdr_fixture do |fixture, path|
    project = workspace_directory(fixture)
    context = { home: fixture[:home], picker: workspace_picker([project]), environment: {}, tty: false }
    2.times { equal 0, Herdr.run_workspaces_herdr(%w[start --ai claude], **context) }
    state = herdr_state(path)
    equal 1, state['workspaces'].length
    equal File.basename(project), state['workspaces'].first['label']
    equal %w[nvim claude shell], state['workspaces'].first['tabs'].map { |tab| tab['label'] }
    equal ['nvim .', Archon::Workspaces::CLAUDE_COMMAND], state['workspaces'].first['tabs'].flat_map { |tab| tab['commands'] }
    equal project, state['workspaces'].first['cwd']
    equal 0, state['attachments']
    equal 1, state['calls'].count { |call| call == ['server'] }
    equal 0, Herdr.run_workspaces_herdr(['start'], **context.merge(tty: true))
    equal 1, herdr_state(path)['attachments']
    equal herdr_state(path)['workspaces'].first['workspace_id'], herdr_state(path)['focused']
    equal 0, Herdr.run_workspaces_herdr(['start'], **context.merge(tty: true, environment: { 'HERDR_ENV' => '1' }))
    equal 1, herdr_state(path)['attachments']
    update_herdr_state(path) { |state| state['failure'] = { 'prefix' => [], 'remaining' => 1 } }
    equal 1, Herdr.run_workspaces_herdr(['start'], **context.merge(tty: true))
  end
end

test('Herdr uses exact folder labels and remembers distinct IDs for same-named projects') do
  herdr_fixture do |fixture, path|
    projects = %w[personal/one/a.b personal/two/a.b].map { |relative| workspace_directory(fixture, relative) }
    context = { home: fixture[:home], picker: workspace_picker(projects), environment: {}, tty: false }
    equal 0, Herdr.run_workspaces_herdr(['start'], **context)
    state = herdr_state(path)
    equal ['a.b', 'a.b'], state['workspaces'].map { |workspace| workspace['label'] }
    ids = state['workspaces'].map { |workspace| workspace['workspace_id'] }
    equal 2, ids.uniq.length
    selection_path = Archon::WorkspaceProjects.selection_path('herdr', home: fixture[:home], state_home: ENV['XDG_STATE_HOME'])
    equal projects.zip(ids).to_h, JSON.parse(File.read(selection_path))['workspace_ids']
    equal 0, Herdr.run_workspaces_herdr(['start'], **context.merge(picker: workspace_picker([projects.last]), tty: true))
    equal ids.last, herdr_state(path)['focused']
    equal 0, Herdr.run_workspaces_herdr(['stop'], **context)
    equal 0, Herdr.run_workspaces_herdr(['start'], **context.merge(picker: workspace_picker(projects.reverse)))
    equal ids, herdr_state(path)['workspaces'].map { |workspace| workspace['workspace_id'] }
    equal projects.zip(ids).to_h, JSON.parse(File.read(selection_path))['workspace_ids']
    update_herdr_state(path) { |value| value['workspaces'].delete_at(0) }
    equal 0, Herdr.run_workspaces_herdr(['start'], **context)
    state = herdr_state(path)
    equal 2, state['workspaces'].length
    equal ids.last, state['workspaces'].first['workspace_id']
    assert !ids.include?(state['workspaces'].last['workspace_id'])
  end
end

test('Herdr renames a remembered workspace to its folder and preserves manually created same-named workspaces') do
  herdr_fixture do |fixture, path|
    project = workspace_directory(fixture)
    seed_herdr_workspaces(path, ['renamed by hand', File.basename(project)])
    selection_path = Archon::WorkspaceProjects.selection_path('herdr', home: fixture[:home], state_home: ENV['XDG_STATE_HOME'])
    Archon::WorkspaceProjects.save_selection(selection_path, { 'projects' => [project], 'workspace_ids' => { project => 'w7' } })
    before = herdr_state(path)['workspaces'].map { |workspace| workspace['workspace_id'] }
    context = { home: fixture[:home], picker: workspace_picker([project]), environment: {}, tty: true }
    2.times { equal 0, Herdr.run_workspaces_herdr(['start'], **context) }
    state = herdr_state(path)
    equal before, state['workspaces'].map { |workspace| workspace['workspace_id'] }
    equal [File.basename(project)] * 2, state['workspaces'].map { |workspace| workspace['label'] }
    equal 'w7', state['focused']
    equal 1, state['calls'].count { |call| call.first(2) == %w[workspace rename] }
    assert state['calls'].none? { |call| call.first(2) == %w[workspace create] }
  end
end

test('Herdr rolls back a new workspace if remembering its ID fails') do
  definition = { session: 'example', directory: '/fixture/project', label: 'project' }
  created = { 'workspace' => { 'workspace_id' => 'w401', 'label' => 'project' },
              'tab' => { 'tab_id' => 'w401:t709' }, 'root_pane' => { 'pane_id' => 'w401:p901' } }
  calls = []
  request = ->(arguments) { calls << arguments; created }
  result = Herdr.create_workspace(definition, Archon::Workspaces.editor_tabs, request) { raise 'cannot save IDs' }
  equal({ status: 1, cleanup_status: 0 }, result)
  equal %w[workspace close w401], calls.last
end

test('Herdr picker cancellation, empty discovery and empty selections do not start a server') do
  herdr_fixture do |fixture, path|
    operation = ->(*_, **_) { raise 'must not operate on backend' }
    context = { home: fixture[:home], capture: operation, start_server: operation }
    equal 0, Herdr.run_workspaces_herdr(['start'], **context, picker: operation)
    workspace_directory(fixture)
    equal 0, Herdr.run_workspaces_herdr(['start'], **context, picker: ->(*_, **_) { nil })
    equal 0, Herdr.run_workspaces_herdr(['start'], **context, picker: workspace_picker([]))
    equal [], herdr_state(path)['calls']
  end
end

test('Herdr pane run failures roll back newly created workspaces, continue, and allow retry') do
  herdr_fixture do |fixture, path|
    projects = %w[cloned/one cloned/two].map { |relative| workspace_directory(fixture, relative) }
    context = { home: fixture[:home], picker: workspace_picker(projects), environment: {}, tty: false }
    update_herdr_state(path) { |state| state['failure'] = { 'prefix' => %w[pane run], 'remaining' => 1 } }
    equal 1, Herdr.run_workspaces_herdr(['start'], **context)
    equal [projects.last], herdr_state(path)['workspaces'].map { |workspace| workspace['cwd'] }
    assert herdr_state(path)['calls'].any? { |call| call.first(2) == %w[workspace close] }
    equal 0, Herdr.run_workspaces_herdr(['start'], **context)
    equal projects.sort, herdr_state(path)['workspaces'].map { |workspace| workspace['cwd'] }.sort
  end
end

test('Herdr errors and malformed responses fail without creating resources') do
  fixture do |fixture|
    project = workspace_directory(fixture)
    ['', 'invalid JSON', '[]', '{"error":{"message":"denied"}}', '{"result":{}}'].each do |output|
      equal 1, Herdr.run_workspaces_herdr(['start'], home: fixture[:home], picker: workspace_picker([project]),
        capture: ->(*_) { { status: 0, output: output } }, start_server: ->(*) { raise 'must not start server' })
    end
    equal 1, Herdr.run_workspaces_herdr(['stop'], capture: ->(*_) { { status: 1, output: 'not found' } })
  end
end

test('failed Herdr server startup produces a private log and creates no workspaces') do
  herdr_fixture do |fixture, path|
    project = workspace_directory(fixture)
    update_herdr_state(path) { |state| state['failure'] = { 'prefix' => ['server'], 'remaining' => 1 } }
    state_home = File.join(fixture[:root], 'separate state')
    equal 1, Herdr.run_workspaces_herdr(['start'], home: fixture[:home], state_home: state_home, picker: workspace_picker([project]),
                                        environment: {}, tty: false)
    equal [], herdr_state(path)['workspaces']
    log = File.join(state_home, 'archon/workspaces-herdr-server.log')
    assert !File.exist?(File.join(ENV.fetch('XDG_STATE_HOME'), 'archon/workspaces-herdr-server.log'))
    assert File.read(log).include?('injected Herdr failure')
    equal 0o600, File.stat(log).mode & 0o777
  end
end

test('Herdr stop tolerates a stopped session and stops an empty dedicated session') do
  herdr_fixture do |_, path|
    2.times { equal 0, run_archon(%w[w h stop])[:status] }
    update_herdr_state(path) { |state| state['running'] = true }
    equal 0, run_archon(%w[w h stop])[:status]
    assert !herdr_state(path)['running']
  end
end

test('Herdr stop shuts down its entire dedicated session, including extras, with no project or state requirements') do
  herdr_fixture do |fixture, path|
    seed_herdr_workspaces(path, %w[project extra ~])
    update_herdr_state(path) { |state| state['client_attached'] = true }
    2.times { equal 0, run_archon(%w[w h stop])[:status] }
    state = herdr_state(path)
    assert !state['running']
    equal 1, state['calls'].count { |call| call == %w[session stop archon --json] }
    assert state['calls'].none? { |call| call.first(2) == %w[workspace close] }
    assert !File.exist?(File.join(fixture[:home], 'projects'))
    assert !File.exist?(File.join(ENV['XDG_STATE_HOME'], 'archon/herdr.json'))
  end
end

test('Herdr detached stop preserves its target, logs failures, and allows retry') do
  herdr_fixture do |_, path|
    seed_herdr_workspaces(path, %w[one two extra])
    update_herdr_state(path) { |state| state['failure'] = { 'prefix' => %w[session stop], 'remaining' => 1 } }
    environment = { 'HERDR_ENV' => '1', 'HERDR_SESSION' => 'unrelated', 'HERDR_SOCKET_PATH' => '/unused/socket' }
    result = run_archon(%w[w h stop], environment)
    equal 1, result[:status]
    assert result[:stderr].include?('Workspace shutdown failed; see')
    assert herdr_state(path)['running']
    log = File.join(ENV['XDG_STATE_HOME'], 'archon/workspaces-herdr-stop.log')
    assert File.read(log).include?('Herdr session stop failed')
    equal 0o600, File.stat(log).mode & 0o777
    equal 0, run_archon(%w[w h stop], environment)[:status]
    assert !herdr_state(path)['running']
  end
end

test('Herdr validates shutdown options before delegating') do
  calls = []
  context = { environment: { 'HERDR_ENV' => '1' }, stop_detached: ->(arguments, _) { calls << arguments; 7 } }
  equal 7, Herdr.run_workspaces_herdr(['stop'], **context)
  equal 7, Herdr.run_workspaces_herdr(['kill'], **context)
  [%w[stop -g current], %w[kill --ai codex], %w[stop extra]].each do |arguments|
    equal 2, Herdr.run_workspaces_herdr(arguments, **context)
  end
  equal [['stop'], ['kill']], calls
end

test('Herdr kill clears running and stopped sessions and default layouts, preserving configuration and projects') do
  herdr_fixture do |fixture, path|
    seed_herdr_workspaces(path, %w[project extra])
    project = workspace_directory(fixture)
    config = File.join(ENV.fetch('XDG_CONFIG_HOME'), 'herdr')
    FileUtils.mkdir_p(config)
    %w[session.json session-history.json config.toml plugins.json].each { |name| File.write(File.join(config, name), 'keep') }
    selection_path = Archon::WorkspaceProjects.selection_path('herdr', home: fixture[:home], state_home: ENV['XDG_STATE_HOME'])
    Archon::WorkspaceProjects.save_selection(selection_path, { 'projects' => [project], 'workspace_ids' => { project => 'w7' } })
    update_herdr_state(path) do |state|
      state['other_sessions'] = [{ 'name' => 'default', 'running' => true }, { 'name' => 'outside', 'running' => true }, { 'name' => 'idle', 'running' => false }]
    end
    2.times { equal 0, run_archon(%w[w h kill])[:status] }
    state = herdr_state(path)
    assert !state['running'] && state['other_sessions'].none? { |session| session['running'] }
    equal [], state['workspaces']
    equal ['default'], state['other_sessions'].map { |session| session['name'] }
    equal %w[archon outside idle], state['calls'].select { |call| call.first(2) == %w[session delete] }.map { |call| call[2] }
    equal %w[archon default outside], state['calls'].select { |call| call.first(2) == %w[session stop] }.map { |call| call[2] }
    %w[session.json session-history.json].each { |name| assert !File.exist?(File.join(config, name)) }
    %w[config.toml plugins.json].each { |name| equal 'keep', File.read(File.join(config, name)) }
    equal({ 'projects' => [project] }, JSON.parse(File.read(selection_path)))
    assert File.directory?(project)
    state['targets'].each do |target, arguments|
      equal arguments[2], target if [%w[session stop], %w[session delete]].include?(arguments.first(2))
    end
    Archon::WorkspaceProjects.save_selection(selection_path, { 'projects' => [project], 'workspace_ids' => { project => 'w7' } })
    equal 0, run_archon(%w[w h kill])[:status]
    equal({ 'projects' => [project] }, JSON.parse(File.read(selection_path)))
  end
end

test('Herdr kill continues after a session failure and its detached worker can retry') do
  herdr_fixture do |_, path|
    seed_herdr_workspaces(path, ['project'])
    update_herdr_state(path) do |state|
      state['failure'] = { 'prefix' => %w[session stop], 'remaining' => 1 }
      state['other_sessions'] = [{ 'name' => 'outside', 'running' => true }]
    end
    environment = { 'HERDR_ENV' => '1', 'HERDR_SESSION' => 'outside', 'HERDR_SOCKET_PATH' => '/unused/socket' }
    result = run_archon(%w[w h kill], environment)
    equal 1, result[:status]
    assert herdr_state(path)['running']
    equal [], herdr_state(path)['other_sessions']
    assert result[:stderr].include?('Workspace shutdown failed; see')
    equal 0, run_archon(%w[w h kill], environment)[:status]
    assert !herdr_state(path)['running']
  end
end

test('Herdr kill then start creates only newly selected projects and launches their tools') do
  herdr_fixture do |fixture, path|
    projects = %w[personal/one/same personal/two/same cloned/new cloned/old].map { |relative| workspace_directory(fixture, relative) }
    context = { home: fixture[:home], environment: {}, tty: false }
    equal 0, Herdr.run_workspaces_herdr(['start'], **context, picker: workspace_picker([*projects.first(2), projects.last]))
    equal 0, Herdr.run_workspaces_herdr(['kill'], **context)
    selected = [projects[2], projects[1], projects.first]
    2.times { equal 0, Herdr.run_workspaces_herdr(['start'], **context, picker: workspace_picker(selected)) }
    workspaces = herdr_state(path)['workspaces']
    equal selected, workspaces.map { |workspace| workspace['cwd'] }
    workspaces.each do |workspace|
      equal %w[nvim claude shell], workspace['tabs'].map { |tab| tab['label'] }
      equal ['nvim .', Archon::Workspaces::CLAUDE_COMMAND], workspace['tabs'].flat_map { |tab| tab['commands'] }
    end
  end
end

test('Herdr kill reports layout cleanup and session deletion failures, continues and allows retry') do
  herdr_fixture do |_, path|
    seed_herdr_workspaces(path, ['project'])
    config = File.join(ENV.fetch('XDG_CONFIG_HOME'), 'herdr')
    layout = File.join(config, 'session.json')
    FileUtils.mkdir_p(layout)
    update_herdr_state(path) do |state|
      state['failure'] = { 'prefix' => %w[session delete], 'remaining' => 1 }
      state['other_sessions'] = [{ 'name' => 'default', 'running' => false }, { 'name' => 'outside', 'running' => true }]
    end
    result = run_archon(%w[w h kill])
    equal 1, result[:status]
    assert result[:stderr].include?('Herdr session delete failed')
    assert result[:stderr].include?('session.json')
    equal ['default'], herdr_state(path)['other_sessions'].map { |session| session['name'] }
    assert !herdr_state(path)['running']
    FileUtils.rmdir(layout)
    equal 0, run_archon(%w[w h kill])[:status]
    equal [], herdr_state(path)['workspaces']
  end
end
