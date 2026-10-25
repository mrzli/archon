require_relative '../codex_tmux_fixture'
require 'socket'

test('tmux restart skips stale sockets and preserves real panes, shell processes, directories and resume arguments') do
  with_codex_tmux do |fixture, tmux, project, log, command|
    socket_directory = File.join(fixture[:root], "tmux-#{Process.uid}")
    FileUtils.mkdir_p(socket_directory)
    UNIXServer.new(File.join(socket_directory, 'stopped')).close
    tmux.call('new-window', '-t', 'test', '-n', 'other', 'sleep', '60')
    pane = tmux.call('list-panes', '-t', 'test:0', '-F', '#{pane_id}')
    shell_pid = tmux.call('display-message', '-p', '-t', pane, '#{pane_pid}')
    tmux.call('send-keys', '-t', pane, '-l', command)
    tmux.call('send-keys', '-t', pane, 'Enter')
    100.times do
      break if File.exist?(log)
      sleep 0.02
    end
    assert File.exist?(log), 'fake Codex did not start'
    result = run_archon(%w[agents restart], 'TMUX' => "#{fixture[:root]}/codex.sock,1,0", 'TMUX_TMPDIR' => fixture[:root])
    equal 0, result[:status]
    assert result[:stdout].include?('Sent restart commands to 1/1'), result.inspect
    100.times do
      break if File.readlines(log).length >= 2
      sleep 0.01
    end
    launches = File.readlines(log).map { |line| JSON.parse(line) }
    equal 2, launches.length
    assert launches[0]['pid'] != launches[1]['pid']
    equal [project] * 2, launches.map { |launch| launch['cwd'] }
    equal ['resume', '--last', '-m', 'test-model', '-C', project], launches.last['args']
    equal shell_pid, tmux.call('display-message', '-p', '-t', pane, '#{pane_pid}')
    equal 2, tmux.call('list-windows', '-t', 'test', '-F', '#{window_id}').lines.length
  end
end
