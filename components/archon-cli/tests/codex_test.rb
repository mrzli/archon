require_relative 'test_helpers'

def codex_terminals(count: 2, stuck: false)
  states = count.times.map do |index|
    { pid: index + 100, shell: false, screen: 'Ready', calls: [] }
  end
  panes = states.each_index.map { |index| { backend: :herdr, server: 'test', id: index } }
  terminals = Object.new
  terminals.define_singleton_method(:discover) { |_program, run:| [panes, []] }
  terminals.define_singleton_method(:process_info) do |pane, _program, run:|
    state = states.fetch(pane[:id])
    state[:shell] ? { shell: true } :
      { pid: state[:pid], argv: ['codex', 'resume', '--last', '--model', 'test-model', '-c', 'test="a b"'],
        cwd: "/tmp/project with spaces; echo bad" }
  end
  terminals.define_singleton_method(:read) { |*| raise 'Must not inspect terminal output' }
  terminals.define_singleton_method(:terminate) do |info, signal|
    state = states.find { |item| item[:pid] == info[:pid] }
    state[:calls] << signal
    state[:shell] = true unless stuck && signal == 'TERM'
  end
  terminals.define_singleton_method(:running?) do |info|
    states.any? { |state| state[:pid] == info[:pid] && !state[:shell] }
  end
  terminals.define_singleton_method(:submit) do |pane, text, run:|
    state = states.fetch(pane[:id])
    state[:calls] << text
    state[:shell] = false
    state[:pid] += 1000
    state[:screen] = '? for shortcuts'
  end
  [terminals, states]
end

def restart_codex(terminals)
  capture do
    Archon::Codex.run_codex(['restart'], terminals: terminals, run: ->(*) { raise 'unexpected external command' },
                           wait: -> {})
  end
end

test('Codex restarts every pane using latest conversation and preserves launch options') do
  terminals, states = codex_terminals
  status, output, error = restart_codex(terminals)
  equal 0, status
  equal '', error
  assert output.include?('Sent restart commands to 2/2')
  states.each do |state|
    equal 'TERM', state[:calls].first
    command = Shellwords.split(state[:calls][1])
    equal ['cd', '--', '/tmp/project with spaces; echo bad', '&&', 'codex', 'resume', '--last',
           '--model', 'test-model', '-c', 'test="a b"', '-C', '/tmp/project with spaces; echo bad'], command
    assert state[:calls][1].include?('--last')
  end
end

test('TERM-resistant processes are killed before relaunch without UI checks') do
  terminals, states = codex_terminals(count: 1, stuck: true)
  equal 0, restart_codex(terminals).first
  equal ['TERM', 'KILL'], states.first[:calls].first(2)
  assert states.first[:calls].last.include?('codex resume --last')
end

test('a Codex pane without an underlying shell is left running') do
  terminals, states = codex_terminals(count: 1)
  terminals.define_singleton_method(:process_info) do |pane, _program, run:|
    { pid: 123, argv: ['codex'], cwd: '/project', no_shell: true }
  end
  status, _, error = restart_codex(terminals)
  equal 1, status
  equal [], states.first[:calls]
  assert error.include?('no underlying shell')
end

test('an explicit working directory is not overridden by the process directory') do
  terminals, states = codex_terminals(count: 1)
  original_info = terminals.method(:process_info)
  terminals.define_singleton_method(:process_info) do |pane, _program, run:|
    info = original_info.call(pane, 'codex', run: run)
    info[:argv] += ['--cd', '/different project'] if info[:argv]
    info
  end
  equal 0, restart_codex(terminals).first
  arguments = Shellwords.split(states.first[:calls][1])
  equal '/different project', arguments[arguments.index('--cd') + 1]
  assert !arguments.include?('-C')
end

test('resume removes selectors, prompts and images but preserves directory overrides') do
  equal ['--profile', 'work', '--cd', '/old', '-c', 'foo="bar baz"', '--no-daemon'],
        Archon::Codex.resume_options(['codex', '--profile=work', 'fork', '--last',
                                      '--cd', '/old', '-i', '/image', '-c', 'foo="bar baz"',
                                      '--no-daemon', 'original prompt'])
  raises(/Unsupported launch option/) { Archon::Codex.resume_options(%w[codex --future-option]) }
  raises(/Unsupported launch option/) { Archon::Codex.resume_options(%w[codex --worktree]) }
  raises(/Unsupported Codex command/) { Archon::Codex.resume_options(%w[codex exec do-something]) }
end

test('discovery reports broken Herdr sessions and continues with the others') do
  fixture do |fixture|
    run = lambda do |command, arguments|
      equal 'herdr', command
      if arguments == %w[session list --json]
        { status: 0, stdout: JSON.generate(sessions: [{ name: 'broken', running: true }, { name: 'ok', running: true }]) }
      elsif arguments[1] == 'broken'
        { status: 1, stdout: '', stderr: 'connection failed' }
      else
        { status: 0, stdout: JSON.generate(result: { agents: [{ agent: 'codex', pane_id: 'w1:p2' }] }) }
      end
    end
    panes, errors = Archon::AgentTerminals.discover('codex', run: run, env: { 'TMUX_TMPDIR' => fixture[:root] })
    equal ['ok'], panes.map { |pane| pane[:server] }
    equal 1, errors.length
    assert errors.first.include?('connection failed')
  end
end

test('Codex empty discovery is a successful no-op') do
  terminals, = codex_terminals(count: 0)
  status, output, error = restart_codex(terminals)
  equal 0, status
  equal "No Codex CLI sessions running.\n", output
  equal '', error
end

test('Codex discovery ignores stopped tmux servers but reports real discovery errors') do
  fixture do |fixture|
    socket = File.join(fixture[:root], 'tmux.sock')
    ["no server running on #{socket}", "error connecting to #{socket} (No such file or directory)", 'no sessions',
     "error connecting to #{socket} (Permission denied)", 'server exited unexpectedly'].each do |message|
      run = lambda do |command, _arguments|
        if command == 'herdr'
          { status: 0, stdout: JSON.generate(sessions: []) }
        else
          { status: 1, stdout: message, stderr: '' }
        end
      end
      panes, errors = Archon::AgentTerminals.discover('codex', run: run,
        env: { 'TMUX_TMPDIR' => fixture[:root], 'TMUX' => "#{socket},123,0" })
      equal [], panes
      if message.include?('Permission denied') || message == 'server exited unexpectedly'
        equal 1, errors.length
        assert errors.first.include?(message)
      else
        equal [], errors
      end
    end
  end
end

test('Codex usage never invokes terminal discovery') do
  fixture do
    [[], ['unknown'], ['restart', 'extra']].each do |arguments|
      result = run_archon(['codex', *arguments])
      equal 2, result[:status]
      assert result[:stderr].include?('Usage: archon codex restart')
    end
    [%w[--help], %w[help], %w[restart --help]].each do |arguments|
      equal 0, run_archon(['codex', *arguments])[:status]
    end
  end
end

test('Herdr adapter discovers all running sessions and uses explicit pane targets') do
  fixture do |fixture|
    calls = []
    run = lambda do |command, arguments|
      calls << [command, arguments]
      equal 'herdr', command
      response = if arguments == %w[session list --json]
        { sessions: [{ name: 'one', running: true }, { name: 'two', running: true }, { name: 'old', running: false }] }
      elsif arguments.last(2) == %w[agent list]
        { result: { agents: [{ agent: 'codex', pane_id: 'w1:p2' }, { agent: 'claude', pane_id: 'w2:p3' }] } }
      elsif arguments.include?('process-info')
        { result: { process_info: { shell_pid: 1, foreground_process_group_id: 2,
                    foreground_processes: [{ pid: 2, argv: %w[codex resume --last], cwd: '/project' }] } } }
      end
      { status: 0, stderr: '', stdout: response ? JSON.generate(response) : 'Session: plain text' }
    end
    panes, errors = Archon::AgentTerminals.discover('codex', run: run, env: { 'TMUX_TMPDIR' => fixture[:root] })
    equal [], errors
    equal %w[one two], panes.map { |pane| pane[:server] }
    pane = panes.first
    equal 2, Archon::AgentTerminals.process_info(pane, 'codex', run: run)[:pid]
    Archon::AgentTerminals.submit(pane, 'codex resume --last', run: run)
    equal ['herdr', ['--session', 'one', 'pane', 'run', 'w1:p2', 'codex resume --last']], calls.last
  end
end

test('the entire batch is stopped before any launch, with one shared wait') do
  terminals, states = codex_terminals(count: 20)
  original = terminals.method(:submit)
  submissions = 0
  terminals.define_singleton_method(:submit) do |pane, text, run:|
    assert states.all? { |state| state[:calls].include?('TERM') }
    submissions += 1
    original.call(pane, text, run: run)
  end
  waits = 0
  status, = capture do
    Archon::Codex.run_codex(['restart'], terminals: terminals, run: ->(*) { raise 'unexpected command' },
                           wait: -> { waits += 1 })
  end
  equal 0, status
  equal 20, submissions
  equal 1, waits
end

test('a failed launch submission does not leave the rest of the stopped batch stranded') do
  terminals, states = codex_terminals
  original = terminals.method(:submit)
  terminals.define_singleton_method(:submit) do |pane, text, run:|
    raise 'terminal unavailable' if pane[:id].zero?
    original.call(pane, text, run: run)
  end
  status, _, error = restart_codex(terminals)
  equal 1, status
  assert error.include?('terminal unavailable')
  assert states.last[:calls].last.include?('codex resume --last')
end

test('Ctrl+C during terminal discovery exits quietly with status 130') do
  fixture do |fixture|
    marker = File.join(fixture[:root], 'discovery-started')
    write_executable(File.join(fixture[:bin], 'herdr'), "#!/bin/sh\ntouch #{Shellwords.escape(marker)}\nexec sleep 20\n")
    Open3.popen3(RbConfig.ruby, ARCHON, 'codex', 'restart', pgroup: true) do |input, output, error, child|
      input.close
      begin
        100.times do
          break if File.exist?(marker)
          sleep 0.01
        end
        assert File.exist?(marker)
        Process.kill('INT', child.pid)
        assert child.join(3), 'cancellation did not finish promptly'
        equal 130, child.value.exitstatus
        equal '', output.read
        equal "Codex restart cancelled.\n", error.read
      ensure
        if child.alive?
          Process.kill('KILL', -child.pid)
          child.join
        end
      end
    end
  end
end
