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
  definition = { session: 'example', directory: '/fixture/project' }
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

test('Herdr creates selected uniform workspaces, repeats safely and attaches only outside Herdr') do
  herdr_fixture do |fixture, path|
    project = workspace_directory(fixture)
    context = { home: fixture[:home], picker: workspace_picker([project]), environment: {}, tty: false }
    2.times { equal 0, Herdr.run_workspaces_herdr(%w[start --ai claude], **context) }
    state = herdr_state(path)
    equal 1, state['workspaces'].length
    equal %w[nvim claude shell], state['workspaces'].first['tabs'].map { |tab| tab['label'] }
    equal ['nvim .', 'claude --continue'], state['workspaces'].first['tabs'].flat_map { |tab| tab['commands'] }
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
        capture: ->(*_) { { status: 0, output: output } }, start_server: ->(_) { raise 'must not start server' })
    end
    equal 1, Herdr.run_workspaces_herdr(['stop'], capture: ->(*_) { { status: 1, output: 'not found' } })
  end
end

test('failed Herdr server startup produces a private log and creates no workspaces') do
  herdr_fixture do |fixture, path|
    project = workspace_directory(fixture)
    update_herdr_state(path) { |state| state['failure'] = { 'prefix' => ['server'], 'remaining' => 1 } }
    equal 1, Herdr.run_workspaces_herdr(['start'], home: fixture[:home], picker: workspace_picker([project]), environment: {}, tty: false)
    equal [], herdr_state(path)['workspaces']
    log = File.join(ENV.fetch('XDG_STATE_HOME'), 'archon/workspaces-herdr-server.log')
    assert File.read(log).include?('injected Herdr failure')
    equal 0o600, File.stat(log).mode & 0o777
  end
end

test('ambiguous Herdr workspace labels are refused without creating resources') do
  herdr_fixture do |fixture, path|
    project = workspace_directory(fixture)
    label = Archon::Workspaces.project_definitions([project]).first[:session]
    seed_herdr_workspaces(path, [label, label])
    status, _, error = capture do
      Herdr.run_workspaces_herdr(['start'], home: fixture[:home], picker: workspace_picker([project]), environment: {}, tty: false)
    end
    equal 1, status
    assert error.include?('More than one Herdr workspace is named')
    assert herdr_state(path)['calls'].none? { |call| call.first(2) == %w[workspace create] }
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
