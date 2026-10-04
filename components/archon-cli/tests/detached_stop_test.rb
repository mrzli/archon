require_relative 'workspace_helpers'

test('detached shutdown propagates failure and appends diagnostics to a private log') do
  fixture do |fixture|
    write_executable(File.join(fixture[:bin], 'tmux'), <<~'SH')
      #!/bin/sh
      case "$1" in
        list-sessions) printf 'managed\t1\n';;
        kill-session) echo 'injected kill failure' >&2; exit 1 ;;
        *) exit 2 ;;
      esac
    SH
    2.times do
      result = run_archon(%w[w t stop], 'TMUX' => 'fixture-server')
      equal 1, result[:status]
      assert result[:stderr].include?('Workspace shutdown failed; see')
    end
    log = File.join(ENV.fetch('XDG_STATE_HOME'), 'archon/workspaces-tmux-stop.log')
    content = File.read(log)
    equal 2, content.scan('injected kill failure').length
    assert content.include?('Failed to stop tmux session: managed')
    equal 0o600, File.stat(log).mode & 0o777
  end
end
