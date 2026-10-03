require_relative '../codex_tmux_fixture'

test('twelve-pane restart returns before delayed Codex startup completes') do
  with_codex_tmux do |fixture, tmux, project, log, command|
    panes = [tmux.call('list-panes', '-t', 'test:0', '-F', '#{pane_id}')]
    11.times do |index|
      panes << tmux.call('new-window', '-P', '-F', '#{pane_id}', '-t', 'test', '-n', "codex-#{index}",
                         '-c', project, '/bin/bash', '--noprofile', '--norc')
    end
    panes.each do |pane|
      tmux.call('send-keys', '-t', pane, '-l', "export TEST_CODEX_STARTUP_DELAY=3; #{command}")
      tmux.call('send-keys', '-t', pane, 'Enter')
    end
    200.times do
      break if File.exist?(log) && File.readlines(log).length >= 12
      sleep 0.01
    end
    equal 12, File.readlines(log).length
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = run_archon(%w[codex restart], 'TMUX' => "#{fixture[:root]}/codex.sock,1,0", 'TMUX_TMPDIR' => fixture[:root])
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    equal 0, result[:status]
    assert result[:stdout].include?('Sent restart commands to 12/12'), result.inspect
    assert elapsed < 3, "batch took #{elapsed.round(2)}s before returning"
    assert File.readlines(log).length < 24, 'command waited for delayed startup'
    STDOUT.puts "12-pane batch returned in #{elapsed.round(2)}s with three-second startup delays"
    500.times do
      break if File.readlines(log).length >= 24
      sleep 0.01
    end
    equal 24, File.readlines(log).length
  end
end
