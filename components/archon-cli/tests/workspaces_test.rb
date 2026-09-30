require_relative 'test_helpers'

Workspaces = Archon::Workspaces

def workspace_fixture(fixture)
  paths = ['projects/personal/mrzli-jslib/example/.git', 'projects/personal/mrzli/flashcards-fe',
           'projects/personal/mrzli/flashcards-be'] + Workspaces::PROJECTS.map { |project| "projects/personal/#{project}" }
  paths.each { |path| FileUtils.mkdir_p(File.join(fixture[:home], path)) }
end

test('AI selection defaults to Codex and combines with group selection in either order') do
  equal 'codex', Workspaces.parse_arguments(['start'])[:ai]
  %w[codex claude].each do |ai|
    [['--ai', ai, '--group', 'flashcards'], ['-g', 'flashcards', '--ai', ai]].each do |options|
      equal({ action: 'start', group: 'flashcards', ai: ai }, Workspaces.parse_arguments(['start', *options]))
    end
  end
  [%w[start --ai], %w[start --ai unknown], %w[start -a claude],
   %w[start --ai claude --ai codex], %w[start -g general --group general],
   %w[stop --ai claude], %w[kill --ai claude]].each do |arguments|
    calls = []
    equal 2, Workspaces.run_workspaces(arguments, run: ->(*args) { calls << args }, capture: ->(*args) { calls << args })
    equal [], calls
  end
end

test('Claude selection reaches tmux AI windows in every project group') do
  fixture do |fixture|
    workspace_fixture(fixture)
    calls = []
    run = ->(_, args, **_) { calls << args; args.first == 'has-session' ? 1 : 0 }
    equal 0, Workspaces.run_workspaces(%w[start --ai claude], home: fixture[:home], environment: {}, tty: false, run: run)
    ai_windows = calls.select { |args| args.first == 'new-window' && args.last == 'claude' }
    equal 10, ai_windows.length
    ai_windows.each do |args|
      assert calls.include?(['send-keys', '-t', "#{args[2]}:claude", 'claude --continue', 'Enter'])
    end
    assert calls.none? { |args| args.include?('codex') || args.include?('codex resume --last') }
  end
end

test('tmux session operations preserve command arguments and exit statuses') do
  calls = []
  run = ->(command, arguments, **options) { calls << [command, arguments, options]; arguments.first == 'has-session' ? 1 : 7 }
  tmux = Workspaces.create_tmux(run: run, capture: ->(*_) { { status: 3, output: 'capture output' } })
  equal 0, tmux[:stop_session].call('absent')
  equal 7, tmux[:create_shell_session].call(session: 'main', directory: '/fixture/projects')
  equal 7, tmux[:attach_session].call('main')
  equal 7, tmux[:kill_session].call('main')
  equal({ status: 3, output: 'capture output' }, tmux[:list_sessions].call)
  equal [
    ['tmux', %w[has-session -t absent], { stdio: :ignore }],
    ['tmux', %w[new-session -d -s main -c /fixture/projects -n shell], {}],
    ['tmux', %w[attach-session -t =main], {}], ['tmux', %w[kill-session -t main], {}]
  ], calls
end

[nil, 'bun run dev', 'pnpm run dev'].each do |dev_command|
  test("editor layout and every rollback boundary: #{dev_command || 'no dev window'}") do
    definition = { session: 'editor', directory: '/fixture/space dir', dev_command: dev_command }
    expected = [
      ['new-session', '-d', '-s', 'editor', '-c', definition[:directory], '-n', 'nvim'],
      ['send-keys', '-t', 'editor:nvim', 'nvim .', 'Enter'],
      ['new-window', '-t', 'editor', '-c', definition[:directory], '-n', 'codex'],
      ['send-keys', '-t', 'editor:codex', 'codex resume --last', 'Enter']
    ]
    if dev_command
      expected.concat([['new-window', '-t', 'editor', '-c', definition[:directory], '-n', 'dev'],
                       ['send-keys', '-t', 'editor:dev', dev_command, 'Enter']])
    end
    expected.concat([['new-window', '-t', 'editor', '-c', definition[:directory], '-n', 'shell'],
                     ['select-window', '-t', 'editor:nvim']])
    calls = []
    result = Workspaces.create_editor_session(->(_, arguments) { calls << arguments; 0 }, definition)
    equal({ status: 0 }, result)
    equal expected, calls
    expected.each_index do |failed_index|
      calls = []
      run = ->(_, arguments) { calls << arguments; calls.length == failed_index + 1 ? 1 : 0 }
      result = Workspaces.create_editor_session(run, definition)
      equal 1, result[:status]
      equal failed_index.zero? ? nil : 0, result[:cleanup_status]
      equal expected.take(failed_index + 1) + (failed_index.zero? ? [] : [%w[kill-session -t editor]]), calls
    end
    result = Workspaces.create_editor_session(->(_, args) { args.first == 'new-session' ? 0 : 1 }, definition)
    equal({ status: 1, cleanup_status: 1 }, result)
  end
end

test('workspace routing preserves group selection, ordering, continuation, and kill status') do
  calls = []
  handlers = Workspaces::GROUPS.to_h { |group| [group, ->(action, _, **_) { calls << [action, group]; group == 'flashcards' ? 1 : 0 }] }
  context = { handlers: handlers, tmux: {}, environment: {}, tty: false }
  equal 1, Workspaces.run_workspaces(['start'], **context)
  equal Workspaces::GROUPS.map { |group| ['start', group] }, calls
  calls.clear
  equal 1, Workspaces.run_workspaces(['stop'], **context)
  equal Workspaces::GROUPS.reverse.map { |group| ['stop', group] }, calls
  calls.clear
  equal 0, Workspaces.run_workspaces(%w[start -g general], **context)
  equal [['start', 'general']], calls
  Workspaces::GROUPS.each do |group|
    calls.clear
    Workspaces.run_workspaces(['start', '--group', group], **context)
    equal [['start', group]], calls
  end
  calls.clear
  equal 7, Workspaces.run_workspaces(['kill'], run: ->(command, args) { calls << [command, args]; 7 })
  equal [['tmux', ['kill-server']]], calls
end

test('validated stop inside tmux delegates to its worker and propagates failure') do
  calls = []
  arguments = %w[stop -g general]
  equal 4, Workspaces.run_workspaces(arguments, environment: { 'TMUX' => 'fixture' }, stop_detached: ->(args) { calls << args; 4 })
  equal [arguments], calls
  equal 2, Workspaces.run_workspaces(%w[stop -g invalid], environment: { 'TMUX' => 'fixture' }, stop_detached: ->(_) { raise 'unexpected worker' })
end

test('attachment selects only matching sessions, prefers main, and handles list and attach failures') do
  calls = []
  tmux = {
    list_sessions: -> { { status: 0, output: "unrelated\nproject-mrzli-docs\njslib-a\nflashcards-be\nmain" } },
    attach_session: ->(session) { calls << session; 0 }
  }
  { nil => 'main', 'general' => 'main', 'flashcards' => 'flashcards-be', 'jslibs' => 'jslib-a', 'misc-projects' => 'project-mrzli-docs' }.each do |group, expected|
    equal 0, Workspaces.attach_after_start(group, tmux)
    equal expected, calls.last
  end
  %w[start stop].each do |action|
    calls.clear
    context = { tmux: tmux, handlers: { 'general' => ->(*_, **_) { 0 } }, environment: {}, tty: false }
    equal 0, Workspaces.run_workspaces([action, '-g', 'general'], **context)
    assert calls.empty?
  end
  %w[no\ server\ running no\ sessions error\ connecting].each do |message|
    equal 0, Workspaces.attach_after_start(nil, tmux.merge(list_sessions: -> { { status: 1, output: message } }))
  end
  equal 1, Workspaces.attach_after_start(nil, tmux.merge(list_sessions: -> { { status: 1, output: 'unexpected error' } }))
  equal 7, Workspaces.attach_after_start(nil, tmux.merge(attach_session: ->(_) { 7 }))
end

test('injected tmux reaches real groups, preserves existing sessions, and tolerates repeated stops') do
  fixture do |fixture|
    workspace_fixture(fixture)
    sessions = {}
    creations = []
    tmux = {
      has_session: ->(session) { sessions.key?(session) },
      create_shell_session: ->(definition) { sessions[definition[:session]] = definition; creations << definition; 0 },
      create_editor_session: ->(definition) { sessions[definition[:session]] = definition; creations << definition; { status: 0 } },
      stop_session: ->(session) { sessions.delete(session); 0 },
      kill_session: ->(session) { sessions.delete(session); 0 },
      list_sessions: -> { { status: 0, output: sessions.keys.join("\n") } },
      attach_session: ->(session) { equal 'main', session; 0 }
    }
    context = { home: fixture[:home], tmux: tmux, environment: {}, tty: true }
    2.times { equal 0, Workspaces.run_workspaces(['start'], **context) }
    equal 11, creations.length
    equal 'bun run dev', sessions['flashcards-fe'][:dev_command]
    equal 'pnpm run dev', sessions['flashcards-be'][:dev_command]
    assert sessions.key?('project-mrzli-mrzli-github-io')
    sessions['unrelated'] = {}
    2.times { equal 0, Workspaces.run_workspaces(['stop'], **context) }
    equal ['unrelated'], sessions.keys
  end
end

test('missing group directories are skipped and library discovery excludes hidden and nested repos') do
  fixture do |fixture|
    tmux = { has_session: ->(_) { raise 'unexpected tmux access' } }
    equal 0, Workspaces.manage_general('start', tmux, home: fixture[:home])
    equal 0, Workspaces.manage_flashcards('start', tmux, home: fixture[:home])
    equal 0, Workspaces.manage_misc_projects('start', tmux, home: fixture[:home])
    equal 0, Workspaces.manage_jslibs('start', tmux, home: fixture[:home])
    root = File.join(fixture[:home], 'projects/personal/mrzli-jslib')
    %w[alpha/.git zeta/.git .hidden/.git ignored/nested/.git worktree].each { |path| FileUtils.mkdir_p(File.join(root, path)) }
    File.write(File.join(root, 'worktree/.git'), 'gitdir: unused')
    equal ["#{root}/alpha/", "#{root}/zeta/"], Workspaces.find_libraries(root)
  end
end

test('group failures report rollback errors, continue to later sessions, and allow retry') do
  fixture do |fixture|
    workspace_fixture(fixture)
    sessions = Set.new
    fail_start = true
    tmux = {
      has_session: ->(session) { sessions.include?(session) },
      create_editor_session: ->(definition) {
        if definition[:session] == 'flashcards-fe' && fail_start
          { status: 1, cleanup_status: 1 }
        else
          sessions.add(definition[:session]); { status: 0 }
        end
      },
      stop_session: ->(session) { session == 'flashcards-fe' ? 1 : (sessions.delete(session); 0) }
    }
    result, _, error = capture { Workspaces.manage_flashcards('start', tmux, home: fixture[:home]) }
    equal 1, result
    assert error.include?('Failed to clean up tmux session: flashcards-fe')
    equal Set['flashcards-be'], sessions
    fail_start = false
    equal 0, Workspaces.manage_flashcards('start', tmux, home: fixture[:home])
    equal 1, Workspaces.manage_flashcards('stop', tmux, home: fixture[:home])
    equal Set['flashcards-fe'], sessions
  end
end

test('library stopping tolerates an absent server and reports other list and kill failures') do
  equal 0, Workspaces.manage_jslibs('stop', { list_sessions: -> { { status: 1, output: 'no server running' } } })
  equal 1, Workspaces.manage_jslibs('stop', { list_sessions: -> { { status: 1, output: 'permission denied' } } })
  calls = []
  tmux = { list_sessions: -> { { status: 0, output: "main\njslib-alpha\njslib-beta" } },
           kill_session: ->(session) { calls << session; session == 'jslib-alpha' ? 1 : 0 } }
  equal 1, Workspaces.manage_jslibs('stop', tmux)
  equal %w[jslib-alpha jslib-beta], calls
end

test('signaled subprocesses become operational failures for execution and capture') do
  fixture do |fixture|
    workspace_fixture(fixture)
    write_executable(File.join(fixture[:bin], 'tmux'), "#!/bin/sh\nkill -TERM \"$$\"\n")
    [%w[start -g flashcards], %w[stop -g jslibs], ['kill']].each do |arguments|
      result = run_archon(['workspaces-tmux', *arguments])
      equal 1, result[:status]
      equal nil, result[:signal]
    end
  end
end
