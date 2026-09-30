require_relative 'test_helpers'

[nil, 'misc-projects'].each do |group|
  test("workspace stop survives closing its calling pane: #{group || 'all groups'}") do
    fixture do |fixture|
      socket = File.join(fixture[:root], 'tmux.sock')
      File.symlink('/usr/bin/tmux', File.join(fixture[:bin], 'tmux'))
      tmux = lambda do |*arguments|
        output, error, status = Open3.capture3('/usr/bin/tmux', '-S', socket, '-f', '/dev/null', *arguments)
        assert status.success?, error
        output.strip
      end
      projects = %w[archon docs js-templates learning mrzli-github-io repos skills].map { |name| "project-mrzli-#{name}" }
      other = %w[jslib-example flashcards-fe flashcards-be main]
      begin
        [*projects, *other, 'unrelated'].each do |session|
          tmux.call('new-session', '-d', '-s', session, 'sleep', '60')
        end
        tmux.call('new-window', '-t', '=project-mrzli-archon', '-n', 'stopper', '/usr/bin/env',
          "HOME=#{fixture[:home]}", "XDG_STATE_HOME=#{ENV.fetch('XDG_STATE_HOME')}", "PATH=#{ENV.fetch('PATH')}",
          RbConfig.ruby, File.expand_path('../bin/arc', __dir__), 'wt', 'stop', *(group ? ['-g', group] : []))
        expected = [*(group ? other : []), 'unrelated'].sort
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        loop do
          sessions = tmux.call('list-sessions', '-F', '#S').lines.map(&:strip).sort
          break if sessions == expected
          if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            log = File.join(ENV.fetch('XDG_STATE_HOME'), 'archon/workspaces-stop.log')
            warn File.read(log) if File.exist?(log)
            equal expected, sessions
          end
          sleep 0.05
        end
      ensure
        system('/usr/bin/tmux', '-S', socket, 'kill-server', out: File::NULL, err: File::NULL)
      end
    end
  end
end

test('detached shutdown propagates failure and appends diagnostics to a private log') do
  fixture do |fixture|
    write_executable(File.join(fixture[:bin], 'tmux'), <<~'SH')
      #!/bin/sh
      case "$1" in
        has-session) exit 0 ;;
        kill-session) echo 'injected kill failure' >&2; exit 1 ;;
        *) exit 2 ;;
      esac
    SH
    2.times do
      result = run_archon(%w[wt stop -g general], 'TMUX' => 'fixture-server')
      equal 1, result[:status]
      assert result[:stderr].include?('Workspace shutdown failed; see')
    end
    log = File.join(ENV.fetch('XDG_STATE_HOME'), 'archon/workspaces-stop.log')
    content = File.read(log)
    equal 2, content.scan('injected kill failure').length
    assert content.include?('Failed to stop tmux session: main')
    equal 0o600, File.stat(log).mode & 0o777
  end
end
