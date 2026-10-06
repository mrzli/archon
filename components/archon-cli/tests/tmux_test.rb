require_relative 'workspace_helpers'

Workspaces = Archon::Workspaces
Tmux = Archon::WorkspacesTmux

test('uniform editor layout rolls back each failed creation operation') do
  definition = { session: 'editor', directory: '/fixture/space dir' }
  expected = [
    ['new-session', '-d', '-s', 'editor', '-c', definition[:directory], '-n', 'nvim'],
    ['set-option', '-t', '=editor:', '@archon-managed', '1'],
    ['set-option', '-t', '=editor:', '@archon-project', definition[:directory]],
    ['send-keys', '-t', '=editor:nvim', 'nvim .', 'Enter'],
    ['new-window', '-t', '=editor', '-c', definition[:directory], '-n', 'claude'],
    ['send-keys', '-t', '=editor:claude', Workspaces::CLAUDE_COMMAND, 'Enter']
  ]
  expected.concat([['new-window', '-t', '=editor', '-c', definition[:directory], '-n', 'shell'],
                   ['select-window', '-t', '=editor:nvim']])
  calls = []
  result = Tmux.create_editor_session(->(_, arguments) { calls << arguments; 0 }, definition)
  equal({ status: 0 }, result)
  equal expected, calls
  expected.each_index do |failed_index|
    calls = []
    run = ->(_, arguments) { calls << arguments; calls.length == failed_index + 1 ? 1 : 0 }
    result = Tmux.create_editor_session(run, definition)
    equal 1, result[:status]
    equal failed_index.zero? ? nil : 0, result[:cleanup_status]
    equal expected.take(failed_index + 1) + (failed_index.zero? ? [] : [%w[kill-session -t =editor]]), calls
  end
  result = Tmux.create_editor_session(->(_, args) { args.first == 'new-session' ? 0 : 1 }, definition)
  equal({ status: 1, cleanup_status: 1 }, result)
end


test('AI options and removed group options are validated before any operation') do
  equal({ action: 'start', ai: 'claude' }, Workspaces.parse_arguments(['start'], help: Tmux::HELP))
  equal({ action: 'start', ai: 'codex' }, Workspaces.parse_arguments(%w[start --ai codex], help: Tmux::HELP))
  [%w[start --ai], %w[start --ai unknown], %w[start --ai claude --ai codex],
   %w[start -g current], %w[stop --ai codex], %w[stop -g projects]].each do |arguments|
    operation = ->(*_, **_) { raise 'must not perform operations' }
    equal 2, Tmux.run_workspaces_tmux(arguments, run: operation, capture: operation, picker: operation)
  end
end

test('tmux uses folder names and rejects duplicate names including reserved-character collisions') do
  definitions = Tmux.project_definitions(['/cloned/a.b', '/cloned/plain project', '/personal/one/app'])
  equal ['a-b', 'plain project', 'app'], definitions.map { |definition| definition[:session] }
  raises(/conflicts between projects/) { Tmux.project_definitions(['/cloned/app', '/personal/one/app']) }
  raises(/conflicts between projects/) { Tmux.project_definitions(['/cloned/a.b', '/personal/one/a:b']) }
end

test('tmux selects projects, creates uniform Claude windows and preserves them on repeated starts') do
  fixture do |fixture|
    first = workspace_directory(fixture, 'cloned/space project')
    second = workspace_directory(fixture)
    ENV['TMW_TMUX_STATE'] = File.join(fixture[:root], 'tmux')
    picker = workspace_picker([first, second])
    2.times do
      equal 0, Tmux.run_workspaces_tmux(%w[start --ai claude], home: fixture[:home], environment: {}, tty: false, picker: picker)
    end
    definitions = Tmux.project_definitions([first, second])
    definitions.each do |definition|
      directory = File.join(ENV['TMW_TMUX_STATE'], 'sessions', definition[:session])
      equal %w[nvim claude shell], File.readlines(File.join(directory, 'windows')).map { |line| line.split("\t").first }
      assert File.read(File.join(directory, 'commands')).include?(Workspaces::CLAUDE_COMMAND)
      equal definition[:directory], File.read(File.join(directory, 'root')).strip
    end
    calls = File.read(File.join(ENV['TMW_TMUX_STATE'], 'calls'))
    equal 2, calls.scan(' new-session ').length
    assert !calls.include?('attach-session')
  end
end

test('start continues after failures, reports failed cleanup, skips vanished directories, and can retry') do
  fixture do |fixture|
    projects = ['cloned/one', 'cloned/two', 'cloned/missing'].map { |path| File.join(fixture[:home], 'projects', path) }
    projects.first(2).each { |path| FileUtils.mkdir_p(path) }
    definitions = Workspaces.project_definitions(projects)
    sessions = Set.new
    fail_start = true
    backend = {
      resource_label: 'tmux session', has_session: ->(name) { sessions.include?(name) },
      create_editor_session: ->(definition) {
        if definition == definitions.first && fail_start
          { status: 1, cleanup_status: 1 }
        else
          sessions.add(definition[:session]); { status: 0 }
        end
      }
    }
    status, _, error = capture { Workspaces.start_projects(definitions, backend) }
    equal 1, status
    assert error.include?('Failed to clean up') && error.include?('Skipping')
    equal Set[definitions[1][:session]], sessions
    fail_start = false
    equal 0, Workspaces.start_projects(definitions, backend)
    equal Set.new(definitions.first(2).map { |definition| definition[:session] }), sessions
  end
end

test('validated stop inside tmux delegates once and propagates failure') do
  calls = []
  context = { environment: { 'TMUX' => 'fixture' }, stop_detached: ->(arguments) { calls << arguments; 7 } }
  equal 7, Tmux.run_workspaces_tmux(['stop'], **context)
  equal 2, Tmux.run_workspaces_tmux(%w[stop extra], **context)
  equal [['stop']], calls
end

test('attachment focuses the first selected existing project and propagates failure') do
  definitions = Workspaces.project_definitions(['/one', '/two'])
  calls = []
  backend = { has_session: ->(name) { name == definitions.last[:session] }, attach_session: ->(name) { calls << name; 7 } }
  equal 7, Workspaces.attach_after_start(definitions, backend)
  equal [definitions.last[:session]], calls
  backend[:has_session] = ->(_) { false }
  equal 0, Workspaces.attach_after_start(definitions, backend)
end

test('signaled subprocesses become operational failures for execution and capture') do
  fixture do |fixture|
    write_executable(File.join(fixture[:bin], 'tmux'), "#!/bin/sh\nkill -TERM \"$$\"\n")
    equal 1, Workspaces.run_command('tmux', [])
    equal 1, Tmux.capture_command('tmux', [])[:status]
  end
end

test('stop closes only tagged sessions, ignores saved state and discovery, continues after failure, and tolerates absent servers') do
  fixture do |fixture|
    state = File.join(ENV['XDG_STATE_HOME'], 'archon/workspaces/tmux.json')
    FileUtils.mkdir_p(File.dirname(state))
    File.write(state, '{broken state}')
    calls = []
    run = ->(command, arguments) { calls << [command, arguments]; arguments.last == '=first' ? 7 : 0 }
    context = { home: fixture[:home], environment: {}, picker: ->(*_, **_) { raise 'must not pick' }, run: run }
    capture = ->(*_) { { status: 0, output: "first\t1\nunrelated\t\narchon-lookalike\t\nlast\t1\n" } }
    equal 1, Tmux.run_workspaces_tmux(['stop'], **context, capture: capture)
    equal [['tmux', %w[kill-session -t =first]], ['tmux', %w[kill-session -t =last]]], calls
    calls.clear
    ['no server running', 'no sessions', 'error connecting to /fixture (No such file or directory)',
     'server exited unexpectedly'].each do |message|
      equal 0, Tmux.run_workspaces_tmux(['stop'], **context, capture: ->(*_) { { status: 1, output: message } })
    end
    ['permission denied', 'error connecting to /fixture (Operation not permitted)', ''].each do |message|
      equal 1, Tmux.run_workspaces_tmux(['stop'], **context, capture: ->(*_) { { status: 1, output: message } })
    end
    equal [], calls
    equal '{broken state}', File.read(state)
  end
end

test('starting refuses an untagged name collision and preserves the existing session') do
  calls = []
  run = ->(command, arguments, **_) { calls << [command, arguments]; 0 }
  definitions = [{ session: 'archon-name', directory: '/project' }]
  backend = Tmux.create_tmux(definitions: definitions, run: run, capture: ->(*_) { { status: 0, output: '' } })
  raises(/not managed by Archon/) { backend[:has_session].call('archon-name') }
  equal [['tmux', %w[has-session -t =archon-name]]], calls
  backend = Tmux.create_tmux(definitions: definitions, run: run, capture: ->(_, args) { { status: 0, output: args.last == '@archon-managed' ? '1' : '/project' } })
  equal true, backend[:has_session].call('archon-name')
  backend = Tmux.create_tmux(definitions: definitions, run: run, capture: ->(_, args) { { status: 0, output: args.last == '@archon-managed' ? '1' : '/other/project' } })
  raises(/belongs to another project/) { backend[:has_session].call('archon-name') }
end

test('stop removes tagged sessions after project deletion and preserves untagged lookalikes') do
  fixture do |fixture|
    project = workspace_directory(fixture)
    ENV['TMW_TMUX_STATE'] = File.join(fixture[:root], 'tmux')
    context = { home: fixture[:home], environment: {}, tty: false, picker: workspace_picker([project]) }
    equal 0, Tmux.run_workspaces_tmux(['start'], **context)
    root = File.join(ENV['TMW_TMUX_STATE'], 'sessions')
    FileUtils.mkdir_p(File.join(root, 'archon-unmanaged'))
    FileUtils.rm_rf(File.join(fixture[:home], 'projects'))
    2.times { equal 0, Tmux.run_workspaces_tmux(['stop'], **context) }
    equal ['archon-unmanaged'], Dir.children(root)
  end
end

test('tmux kill shuts down the whole server including untagged sessions and repeats safely') do
  fixture do |fixture|
    project = workspace_directory(fixture)
    ENV['TMW_TMUX_STATE'] = File.join(fixture[:root], 'tmux')
    context = { home: fixture[:home], environment: {}, tty: false, picker: workspace_picker([project]) }
    equal 0, Tmux.run_workspaces_tmux(['start'], **context)
    FileUtils.mkdir_p(File.join(ENV['TMW_TMUX_STATE'], 'sessions/unrelated'))
    2.times { equal 0, run_archon(%w[w t kill])[:status] }
    assert !File.exist?(File.join(ENV['TMW_TMUX_STATE'], 'sessions'))
  end
end

test('tmux kill distinguishes absent servers from errors and detaches before closing its calling pane') do
  calls = []
  %w[stop kill].each do |action|
    equal 7, Tmux.run_workspaces_tmux([action], environment: { 'TMUX' => 'fixture' }, stop_detached: ->(args) { calls << args; 7 })
  end
  equal [%w[stop], %w[kill]], calls
  ['no server running', 'no sessions', 'error connecting to /fixture (No such file or directory)',
   'server exited unexpectedly'].each do |message|
    equal 0, Tmux.run_workspaces_tmux(['kill'], environment: {}, capture: ->(_, args) { equal ['kill-server'], args; { status: 1, output: message } })
  end
  equal 1, Tmux.run_workspaces_tmux(['kill'], environment: {}, capture: ->(*_) { { status: 1, output: 'permission denied' } })
  operation = ->(*_, **_) { raise 'must not perform any operation' }
  [%w[kill extra], %w[kill --ai codex], %w[kill -g current]].each do |arguments|
    equal 2, Tmux.run_workspaces_tmux(arguments, capture: operation, picker: operation)
  end
end
