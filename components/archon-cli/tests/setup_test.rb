require_relative 'test_helpers'

def setup_script(fixture, body)
  write_executable(File.join(fixture[:home], Archon::Setup::REPOSITORY, 'setup.sh'), "#!/bin/sh\n#{body}\n")
end

test('setup runs the Archon checkout setup from any directory and shows its output') do
  fixture do |fixture|
    setup_script(fixture, 'echo "setup ran with $# arguments"')
    output, error, status = Open3.capture3(RbConfig.ruby, ARCHON, 'setup', chdir: fixture[:root])
    equal 0, status.exitstatus
    equal "setup ran with 0 arguments\n", output
    equal '', error
  end
end

test('a failed setup returns status 1') do
  fixture do |fixture|
    setup_script(fixture, 'exit 3')
    result = run_archon(%w[setup])
    equal 1, result[:status]
    assert result[:stderr].include?('Setup failed: setup exited with status 3'), result[:stderr]
  end
end

test('setup reports a missing Archon checkout') do
  fixture do |fixture|
    result = run_archon(%w[setup])
    equal 1, result[:status]
    assert result[:stderr].include?("Archon setup not found: #{fixture[:home]}/#{Archon::Setup::REPOSITORY}/setup.sh"),
           result[:stderr]
  end
end
