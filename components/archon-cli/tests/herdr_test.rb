require_relative 'test_helpers'

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

def all_workspace_directories(fixture)
  paths = ['projects/personal/mrzli-jslib/example/.git', 'projects/personal/mrzli/flashcards-fe',
           'projects/personal/mrzli/flashcards-be'] + Archon::Workspaces::PROJECTS.map { |project| "projects/personal/#{project}" }
  paths.each { |path| FileUtils.mkdir_p(File.join(fixture[:home], path)) }
end

test('Herdr rejects invalid options before inspecting or starting a session') do
  herdr_fixture do |_, path|
    equal 2, run_archon(%w[w h start --group invalid])[:status]
    equal [], herdr_state(path)['calls']
  end
end

test('Herdr creates shared project layouts with silent pane run success, repeats safely, and does not attach') do
  herdr_fixture do |fixture, path|
    all_workspace_directories(fixture)
    2.times do
      result = run_archon(%w[w h start])
      equal 0, result[:status]
      equal '', result[:stderr]
    end
    state = herdr_state(path)
    equal 1, state['calls'].count { |call| call == ['server'] }
    equal 11, state['workspaces'].length
    equal 0, state['attachments']
    equal nil, state['focused']
    state['workspaces'].each do |workspace|
      label = workspace['label']
      expected = label == 'main' ? ['shell'] : %w[nvim codex shell]
      expected = %w[nvim codex dev shell] if label.start_with?('flashcards-')
      equal expected, workspace['tabs'].map { |tab| tab['label'] }
      commands = workspace['tabs'].flat_map { |tab| tab['commands'] }
      unless label == 'main'
        assert commands.include?('nvim .')
        assert commands.include?('codex resume --last')
      end
      assert commands.include?('bun run dev') if label == 'flashcards-fe'
      assert commands.include?('pnpm run dev') if label == 'flashcards-be'
      assert workspace['cwd'].start_with?(fixture[:home])
    end
    state['calls'].select { |call| [%w[workspace create], %w[tab create]].include?(call.first(2)) }.each do |call|
      assert call.include?('--no-focus')
      assert call.include?('--cwd')
    end
  end
end

test('Herdr Claude selection creates Claude tabs and preserves existing workspaces on later starts') do
  herdr_fixture do |fixture, path|
    all_workspace_directories(fixture)
    equal 0, run_archon(%w[w h start --ai claude])[:status]
    workspaces = herdr_state(path)['workspaces']
    equal 11, workspaces.length
    workspaces.reject { |workspace| workspace['label'] == 'main' }.each do |workspace|
      ai_tab = workspace['tabs'].find { |tab| tab['label'] == 'claude' }
      assert ai_tab
      equal ['claude --continue'], ai_tab['commands']
      assert workspace['tabs'].none? { |tab| tab['label'] == 'codex' }
    end
    equal 0, run_archon(%w[w h start --group flashcards --ai codex])[:status]
    equal workspaces, herdr_state(path)['workspaces']
  end
end

test('Herdr selected groups share discovery and skip missing directories without starting a server') do
  herdr_fixture do |fixture, path|
    equal 0, run_archon(%w[w h start])[:status]
    assert !herdr_state(path)['running']
    assert !herdr_state(path)['calls'].include?(['server'])
    library(fixture, 'visible')
    library(fixture, '.hidden')
    result = run_archon(%w[w h start -g jslibs])
    equal 0, result[:status]
    equal ['jslib-visible'], herdr_state(path)['workspaces'].map { |workspace| workspace['label'] }
  end
end

test('Herdr stop runs in reverse group order and preserves unrelated workspaces') do
  herdr_fixture do |fixture, path|
    all_workspace_directories(fixture)
    equal 0, run_archon(%w[w h start])[:status]
    before = herdr_state(path)['workspaces']
    update_herdr_state(path) do |state|
      state['workspaces'] << { 'workspace_id' => 'w9999', 'label' => 'unrelated', 'tabs' => [] }
    end
    2.times { equal 0, run_archon(%w[w h stop])[:status] }
    state = herdr_state(path)
    equal ['unrelated'], state['workspaces'].map { |workspace| workspace['label'] }
    ids = state['calls'].select { |call| call.first(2) == %w[workspace close] }.map { |call| call[2] }
    groups = before.group_by do |workspace|
      case workspace['label']
      when 'main' then 'general'
      when /^flashcards-/ then 'flashcards'
      when /^jslib-/ then 'jslibs'
      else 'misc-projects'
      end
    end
    expected = %w[misc-projects jslibs flashcards general].flat_map { |group| groups.fetch(group).map { |workspace| workspace['workspace_id'] } }
    equal expected, ids
    equal 0, state['attachments']
    assert state['running']
  end
end

test('Herdr named stop only closes the selected group and tolerates an absent session') do
  herdr_fixture do |fixture, path|
    equal 0, run_archon(%w[w h stop -g flashcards])[:status]
    all_workspace_directories(fixture)
    equal 0, run_archon(%w[w h start])[:status]
    equal 0, run_archon(%w[w h stop -g flashcards])[:status]
    workspaces = herdr_state(path)['workspaces']
    equal 9, workspaces.length
    assert workspaces.none? { |workspace| workspace['label'].start_with?('flashcards-') }
  end
end

[%w[stop], %w[stop -g general]].each do |arguments|
  [{}, { 'HERDR_ENV' => '1' }].each do |environment|
    test("Herdr #{arguments.join(' ')} shuts down an empty session, including from a pane: #{environment}") do
      herdr_fixture do |fixture, path|
        FileUtils.mkdir_p(File.join(fixture[:home], 'projects'))
        equal 0, run_archon(%w[w h start -g general])[:status]
        update_herdr_state(path) { |state| state['client_attached'] = true }
        2.times { equal 0, run_archon(['w', 'h', *arguments], environment)[:status] }
        state = herdr_state(path)
        assert !state['running']
        assert state['workspaces'].none? { |workspace| workspace['label'] == '~' }
        equal 1, state['calls'].count { |call| call == %w[session stop archon --json] }
      end
    end
  end
end

test('Herdr stop reports session shutdown failures and allows retry') do
  herdr_fixture do |fixture, path|
    FileUtils.mkdir_p(File.join(fixture[:home], 'projects'))
    equal 0, run_archon(%w[w h start -g general])[:status]
    update_herdr_state(path) do |state|
      state['failure'] = { 'prefix' => %w[session stop], 'remaining' => 1 }
    end
    result = run_archon(%w[w h stop])
    equal 1, result[:status]
    assert result[:stderr].include?('Herdr session stop failed')
    assert herdr_state(path)['running']
    equal 0, run_archon(%w[w h stop])[:status]
    assert !herdr_state(path)['running']
  end
end

test('Herdr stop preserves a pre-existing home workspace') do
  herdr_fixture do |_, path|
    update_herdr_state(path) do |state|
      state['running'] = true
      state['workspaces'] = [{ 'workspace_id' => 'w2', 'label' => '~', 'tabs' => [] }]
    end
    equal 0, run_archon(%w[w h stop])[:status]
    assert herdr_state(path)['running']
    equal ['~'], herdr_state(path)['workspaces'].map { |workspace| workspace['label'] }
  end
end

test('Herdr kill stops only archon and tolerates a stopped session') do
  herdr_fixture do |_, path|
    equal 0, run_archon(%w[w h kill])[:status]
    update_herdr_state(path) { |state| state['running'] = true }
    2.times { equal 0, run_archon(%w[w h kill])[:status] }
    state = herdr_state(path)
    assert !state['running']
    equal 1, state['calls'].count { |call| call == %w[session stop archon --json] }
    assert state['calls'].none? { |call| call == %w[server stop] }
  end
end

test('Herdr attaches only for interactive starts outside Herdr, focusing the selected group') do
  herdr_fixture do |fixture, path|
    all_workspace_directories(fixture)
    arguments = %w[start -g flashcards]
    equal 0, Herdr.run_workspaces_herdr(arguments, tty: true, environment: {})
    state = herdr_state(path)
    equal 1, state['attachments']
    equal state['workspaces'].first['workspace_id'], state['focused']
    equal 0, Herdr.run_workspaces_herdr(arguments, tty: true, environment: { 'HERDR_ENV' => '1' })
    equal 1, herdr_state(path)['attachments']
    equal 0, Herdr.run_workspaces_herdr(arguments, tty: false, environment: {})
    equal 1, herdr_state(path)['attachments']
  end
end

test('Herdr validates stop and kill before delegating from a Herdr pane') do
  calls = []
  context = { environment: { 'HERDR_ENV' => '1' }, stop_detached: ->(arguments) { calls << arguments; 7 } }
  equal 7, Herdr.run_workspaces_herdr(%w[stop -g general], **context)
  equal 7, Herdr.run_workspaces_herdr(['kill'], **context)
  equal 2, Herdr.run_workspaces_herdr(%w[kill extra], **context)
  equal [%w[stop -g general], ['kill']], calls
end

test('Herdr pane run failures roll back the new workspace, continue, and allow retry') do
  herdr_fixture do |fixture, path|
    all_workspace_directories(fixture)
    update_herdr_state(path) { |state| state['failure'] = { 'prefix' => %w[pane run], 'remaining' => 1 } }
    result = run_archon(%w[w h start -g flashcards])
    equal 1, result[:status]
    assert result[:stderr].include?('Failed to start Herdr workspace: flashcards-fe')
    state = herdr_state(path)
    equal ['flashcards-be'], state['workspaces'].map { |workspace| workspace['label'] }
    assert state['calls'].any? { |call| call.first(2) == %w[workspace close] }
    equal 0, run_archon(%w[w h start -g flashcards])[:status]
    equal %w[flashcards-be flashcards-fe], herdr_state(path)['workspaces'].map { |workspace| workspace['label'] }
  end
end

test('Herdr close failures are reported and do not prevent later workspace stops') do
  herdr_fixture do |fixture, path|
    all_workspace_directories(fixture)
    equal 0, run_archon(%w[w h start -g flashcards])[:status]
    update_herdr_state(path) { |state| state['failure'] = { 'prefix' => %w[workspace close], 'remaining' => 1 } }
    result = run_archon(%w[w h stop -g flashcards])
    equal 1, result[:status]
    assert result[:stderr].include?('Failed to stop Herdr workspace: flashcards-fe')
    equal ['flashcards-fe'], herdr_state(path)['workspaces'].map { |workspace| workspace['label'] }
  end
end

test('Herdr errors and malformed responses fail without creating workspaces') do
  ['', 'invalid JSON', '[]', '{"error":{"message":"permission denied"}}', '{"result":{}}'].each do |output|
    result = Herdr.run_workspaces_herdr(['start'], capture: ->(*_) { { status: 0, output: output } },
      start_server: ->(_) { raise 'must not start server' })
    equal 1, result
  end
  equal 1, Herdr.run_workspaces_herdr(['start'], capture: ->(*_) { { status: 1, output: 'herdr not found' } })
end

test('every failed Herdr creation step rolls back only its newly returned workspace ID') do
  definition = { session: 'example', directory: '/fixture/project', dev_command: 'bun run dev' }
  created = { 'workspace' => { 'workspace_id' => 'w401', 'label' => 'example' },
              'tab' => { 'tab_id' => 'w401:t709' }, 'root_pane' => { 'pane_id' => 'w401:p901' } }
  operations = []
  request = ->(arguments) { operations << arguments; created }
  tabs = Archon::Workspaces.editor_tabs(definition)
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

test('failed Herdr server startup produces a private log and creates no workspaces') do
  herdr_fixture do |fixture, path|
    FileUtils.mkdir_p(File.join(fixture[:home], 'projects'))
    update_herdr_state(path) { |state| state['failure'] = { 'prefix' => ['server'], 'remaining' => 1 } }
    result = run_archon(%w[w h start -g general])
    equal 1, result[:status]
    assert result[:stderr].include?('Herdr session archon did not start; see')
    equal [], herdr_state(path)['workspaces']
    log = File.join(ENV.fetch('XDG_STATE_HOME'), 'archon/workspaces-herdr-server.log')
    assert File.read(log).include?('injected Herdr failure')
    equal 0o600, File.stat(log).mode & 0o777
  end
end

test('ambiguous Herdr workspace labels are refused without closing or creating resources') do
  herdr_fixture do |fixture, path|
    FileUtils.mkdir_p(File.join(fixture[:home], 'projects'))
    update_herdr_state(path) do |state|
      state['running'] = true
      state['workspaces'] = [1, 2].map { |id| { 'workspace_id' => "w#{id}", 'label' => 'main' } }
    end
    %w[start stop].each do |action|
      result = run_archon(['w', 'h', action, '-g', 'general'])
      equal 1, result[:status]
      assert result[:stderr].include?('More than one Herdr workspace is named main')
    end
    equal 2, herdr_state(path)['workspaces'].length
    assert herdr_state(path)['calls'].all? { |call| [%w[session list --json], %w[workspace list]].include?(call) }
  end
end

test('Herdr stop worker preserves its target, completes all stops, and returns logged failures') do
  herdr_fixture do |fixture, path|
    all_workspace_directories(fixture)
    equal 0, run_archon(%w[w h start -g flashcards])[:status]
    update_herdr_state(path) { |state| state['failure'] = { 'prefix' => %w[workspace close], 'remaining' => 1 } }
    result = run_archon(%w[w h stop -g flashcards], 'HERDR_ENV' => '1', 'HERDR_SESSION' => 'unrelated', 'HERDR_SOCKET_PATH' => '/unused/socket')
    equal 1, result[:status]
    assert result[:stderr].include?('Workspace shutdown failed; see')
    equal ['flashcards-fe'], herdr_state(path)['workspaces'].map { |workspace| workspace['label'] }
    log = File.join(ENV.fetch('XDG_STATE_HOME'), 'archon/workspaces-herdr-stop.log')
    assert File.read(log).include?('Failed to stop Herdr workspace: flashcards-fe')
    equal 0o600, File.stat(log).mode & 0o777
    equal 0, run_archon(%w[w h kill], 'HERDR_ENV' => '1')[:status]
    assert !herdr_state(path)['running']
  end
end

test('Herdr terminal attachment uses actual terminal detection and reports attachment failures') do
  require 'shellwords'
  herdr_fixture do |fixture, path|
    FileUtils.mkdir_p(File.join(fixture[:home], 'projects'))
    command = Shellwords.join([RbConfig.ruby, ARCHON, 'w', 'h', 'start', '-g', 'general'])
    terminal = ->(env = {}) { Open3.capture3(env.merge('SHELL' => '/bin/bash'), 'timeout', '15s', 'script', '--quiet', '--return', '--command', command, '/dev/null') }
    _, error, status = terminal.call
    assert status.success?, error
    equal 1, herdr_state(path)['attachments']
    _, error, status = terminal.call('HERDR_ENV' => '1')
    assert status.success?, error
    equal 1, herdr_state(path)['attachments']
    update_herdr_state(path) { |state| state['failure'] = { 'prefix' => [], 'remaining' => 1 } }
    equal 1, Herdr.run_workspaces_herdr(%w[start -g general], tty: true, environment: {})
    equal 1, herdr_state(path)['attachments']
  end
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
