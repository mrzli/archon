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
