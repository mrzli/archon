require_relative 'workspace_helpers'

Workspaces = Archon::Workspaces
Tmux = Archon::WorkspacesTmux

test('uniform editor layout rolls back each failed creation operation') do
  definition = { session: 'editor', directory: '/fixture/space dir' }
  expected = [
    ['new-session', '-d', '-s', 'editor', '-c', definition[:directory], '-n', 'nvim'],
    ['set-option', '-t', '=editor:', '@archon-managed', '1'],
    ['send-keys', '-t', '=editor:nvim', 'nvim .', 'Enter'],
    ['new-window', '-t', '=editor', '-c', definition[:directory], '-n', 'codex'],
    ['send-keys', '-t', '=editor:codex', 'codex resume --last', 'Enter']
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
  equal({ action: 'start', ai: 'codex' }, Workspaces.parse_arguments(['start'], help: Tmux::HELP))
  equal({ action: 'start', ai: 'claude' }, Workspaces.parse_arguments(%w[start --ai claude], help: Tmux::HELP))
  [%w[start --ai], %w[start --ai unknown], %w[start --ai claude --ai codex],
   %w[start -g current], %w[stop --ai codex], %w[stop -g projects]].each do |arguments|
    operation = ->(*_, **_) { raise 'must not perform operations' }
    equal 2, Tmux.run_workspaces_tmux(arguments, run: operation, capture: operation, picker: operation)
  end
end

test('project names distinguish owners and punctuation without tmux target syntax') do
  definitions = Workspaces.project_definitions(['/cloned/a.b', '/cloned/a-b', '/personal/one/a.b', '/personal/two/a.b'])
  equal 4, definitions.map { |definition| definition[:session] }.uniq.length
  assert definitions.all? { |definition| definition[:session].match?(/\Aarchon-[a-zA-Z0-9_-]+\z/) }
  equal definitions, Workspaces.project_definitions(definitions.map { |definition| definition[:directory] })
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
    definitions = Workspaces.project_definitions([first, second])
    definitions.each do |definition|
      directory = File.join(ENV['TMW_TMUX_STATE'], 'sessions', definition[:session])
      equal %w[nvim claude shell], File.readlines(File.join(directory, 'windows')).map { |line| line.split("\t").first }
      assert File.read(File.join(directory, 'commands')).include?('claude --continue')
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
    calls = []
    run = ->(command, arguments) { calls << [command, arguments]; arguments.last == '=first' ? 7 : 0 }
    context = { home: fixture[:home], environment: {}, picker: ->(*_, **_) { raise 'must not pick' }, run: run }
    capture = ->(*_) { { status: 0, output: "first\t1\nunrelated\t\narchon-lookalike\t\nlast\t1\n" } }
    equal 1, Tmux.run_workspaces_tmux(['stop'], **context, capture: capture)
    equal [['tmux', %w[kill-session -t =first]], ['tmux', %w[kill-session -t =last]]], calls
    calls.clear
    ['no server running', 'no sessions', 'error connecting to /fixture (No such file or directory)'].each do |message|
      equal 0, Tmux.run_workspaces_tmux(['stop'], **context, capture: ->(*_) { { status: 1, output: message } })
    end
    ['permission denied', 'error connecting to /fixture (Operation not permitted)', ''].each do |message|
      equal 1, Tmux.run_workspaces_tmux(['stop'], **context, capture: ->(*_) { { status: 1, output: message } })
    end
    equal [], calls
    equal 2, Tmux.run_workspaces_tmux(['kill'], **context, capture: ->(*_) { raise 'must not capture' })
  end
end

test('starting refuses an untagged name collision and preserves the existing session') do
  calls = []
  run = ->(command, arguments, **_) { calls << [command, arguments]; 0 }
  backend = Tmux.create_tmux(run: run, capture: ->(*_) { { status: 0, output: '' } })
  raises(/not managed by Archon/) { backend[:has_session].call('archon-name') }
  equal [['tmux', %w[has-session -t =archon-name]]], calls
  backend = Tmux.create_tmux(run: run, capture: ->(*_) { { status: 0, output: '1' } })
  equal true, backend[:has_session].call('archon-name')
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
