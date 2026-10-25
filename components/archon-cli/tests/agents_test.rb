require_relative 'test_helpers'

def recording_restart(calls, claude: 0, codex: 0)
  restarts = { claude: -> { calls << :claude; claude }, codex: -> { calls << :codex; codex } }
  -> { Archon::Agents.restart(**restarts) }
end

test('agents restart runs Claude and then Codex, even when one fails') do
  [[0, 0, 0], [1, 0, 1], [0, 1, 1]].each do |claude, codex, expected|
    calls = []
    equal expected, recording_restart(calls, claude: claude, codex: codex).call
    equal %i[claude codex], calls
  end
end

test('a cancelled Claude restart skips the Codex restart') do
  calls = []
  equal 130, recording_restart(calls, claude: 130).call
  equal %i[claude], calls
end

test('agents reload restarts agents in a new process only after setup succeeds') do
  [[0, 0, 0], [0, 1, 1], [1, nil, 1]].each do |setup_status, restart_status, expected|
    calls = []
    setup = lambda do |arguments|
      calls << [:setup, arguments]
      setup_status
    end
    run = lambda do |command, arguments, stdio:|
      calls << [command, arguments, stdio]
      { status: restart_status }
    end
    status, _, error = capture do
      Archon::Agents.run_agents(['reload'], setup: setup, run: run, restart: -> { raise 'restart must run in a new process' })
    end
    equal expected, status
    restart = [['archon', %w[agents restart], :inherit]]
    equal [[:setup, []], *(setup_status == 0 ? restart : [])], calls
    equal setup_status != 0, error.include?('Agent sessions were not restarted.')
  end
end

test('archon g reload runs setup from the Archon checkout, then the installed agents restart') do
  fixture do |fixture|
    log = File.join(fixture[:root], 'log')
    write_executable(File.join(fixture[:home], Archon::Setup::REPOSITORY, 'setup.sh'), "#!/bin/sh\necho setup >> '#{log}'\n")
    write_executable(File.join(fixture[:bin], 'archon'), "#!/bin/sh\necho \"archon $*\" >> '#{log}'\n")
    result = run_archon(%w[g reload])
    equal 0, result[:status]
    equal ['setup', 'archon agents restart'], File.readlines(log, chomp: true)
  end
end
