require_relative 'test_helpers'

SESSION_IDS = %w[11111111-1111-4111-8111-111111111111 22222222-2222-4222-8222-222222222222].freeze

def claude_terminals(home, count: 2, exit_after: 0, transcripts: true)
  states = count.times.map do |index|
    { pid: index + 100, shell: false, polls: 0, calls: [] }
  end
  states.each_with_index do |state, index|
    FileUtils.mkdir_p(File.join(home, '.claude', 'sessions'))
    File.write(File.join(home, '.claude', 'sessions', "#{state[:pid]}.json"),
               JSON.generate(pid: state[:pid], sessionId: SESSION_IDS.fetch(index), cwd: '/project'))
    next unless transcripts
    FileUtils.mkdir_p(File.join(home, '.claude', 'projects', '-project'))
    File.write(File.join(home, '.claude', 'projects', '-project', "#{SESSION_IDS.fetch(index)}.jsonl"), "{}\n")
  end
  panes = states.each_index.map { |index| { backend: :herdr, server: 'test', id: index } }
  terminals = Object.new
  terminals.define_singleton_method(:discover) do |program, run:|
    equal 'claude', program
    [panes, []]
  end
  terminals.define_singleton_method(:process_info) do |pane, _program, run:|
    state = states.fetch(pane[:id])
    state[:shell] ? { shell: true } :
      { pid: state[:pid], argv: ['claude', '--continue', 'prompt', '--model', 'opus', '--add-dir', '/a b', '/c'],
        cwd: '/tmp/project with spaces; echo bad' }
  end
  terminals.define_singleton_method(:terminate) do |info, signal|
    states.find { |item| item[:pid] == info[:pid] }[:calls] << signal
  end
  terminals.define_singleton_method(:running?) do |info|
    state = states.find { |item| item[:pid] == info[:pid] }
    if !state[:shell] && state[:calls].any?
      state[:polls] += 1
      state[:shell] = state[:calls].include?('KILL') || state[:polls] > exit_after
    end
    !state[:shell]
  end
  terminals.define_singleton_method(:submit) do |pane, text, run:|
    states.fetch(pane[:id])[:calls] << text
  end
  [terminals, states]
end

def restart_claude(home, terminals, wait: -> {})
  capture do
    Archon::Claude.restart(home: home, terminals: terminals, run: ->(*) { raise 'unexpected external command' }, wait: wait)
  end
end

test('Claude resumes each recorded session in its pane and preserves launch options') do
  fixture do |fixture|
    terminals, states = claude_terminals(fixture[:home])
    status, output, error = restart_claude(fixture[:home], terminals)
    equal 0, status
    equal '', error
    assert output.include?('Sent restart commands to 2/2 Claude panes.')
    states.each_with_index do |state, index|
      equal ['TERM'], state[:calls].first(1)
      equal ['cd', '--', '/tmp/project with spaces; echo bad', '&&', 'claude', '--resume', SESSION_IDS[index],
             '--model', 'opus', '--add-dir', '/a b', '/c'], Shellwords.split(state[:calls].last)
    end
  end
end

test('a Claude session without a transcript restarts as a new conversation') do
  fixture do |fixture|
    terminals, states = claude_terminals(fixture[:home], count: 1, transcripts: false)
    equal 0, restart_claude(fixture[:home], terminals).first
    equal ['cd', '--', '/tmp/project with spaces; echo bad', '&&', 'claude', '--model', 'opus', '--add-dir', '/a b', '/c'],
          Shellwords.split(states.first[:calls].last)
  end
end

test('Claude gets a grace period after TERM before KILL is used') do
  fixture do |fixture|
    terminals, states = claude_terminals(fixture[:home], count: 1, exit_after: 5)
    waits = 0
    status, = restart_claude(fixture[:home], terminals, wait: -> { waits += 1 })
    equal 0, status
    assert !states.first[:calls].include?('KILL')
    assert waits > 1
  end
end

test('a missing session record stops the whole batch before any process is stopped') do
  fixture do |fixture|
    terminals, states = claude_terminals(fixture[:home])
    File.delete(File.join(fixture[:home], '.claude', 'sessions', '101.json'))
    status, _, error = restart_claude(fixture[:home], terminals)
    equal 1, status
    assert error.include?('No Claude session record for process 101')
    equal [[], []], states.map { |state| state[:calls] }
  end
end

test('Claude launch options drop selectors and prompts and refuse unsupported launches') do
  equal ['--permission-mode', 'auto', '--effort', 'high', '--mcp-config', 'a.json', 'b.json',
         '--dangerously-skip-permissions'],
        Archon::Claude.launch_options(['claude', '--resume', 'abc', '--permission-mode=auto', '--session-id', 'x',
                                       '--effort', 'high', '--mcp-config', 'a.json', 'b.json',
                                       '--dangerously-skip-permissions', '--fork-session', '-c', 'original prompt'])
  raises(/Unsupported launch option/) { Archon::Claude.launch_options(%w[claude --future-option]) }
  raises(/Unsupported launch option/) { Archon::Claude.launch_options(%w[claude --worktree]) }
  raises(/Unsupported launch option/) { Archon::Claude.launch_options(%w[claude -p hello]) }
  raises(/Unsupported Claude command/) { Archon::Claude.launch_options(%w[claude mcp list]) }
end
