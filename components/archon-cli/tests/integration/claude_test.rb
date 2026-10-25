require_relative '../test_helpers'
require 'shellwords'

test('tmux restart resumes the recorded Claude session after a clean exit in the same pane and shell') do
  fixture do |fixture|
    socket = File.join(fixture[:root], 'claude.sock')
    project = File.join(fixture[:root], 'project with spaces')
    FileUtils.mkdir_p(project)
    File.symlink('/usr/bin/tmux', File.join(fixture[:bin], 'tmux'))
    write_executable(File.join(fixture[:bin], 'herdr'), "#!/bin/sh\nprintf '%s\\n' '{\"sessions\":[]}'\n")
    script = File.join(fixture[:root], 'fake_claude.rb')
    File.write(script, <<~'RUBY')
      require 'fileutils'
      require 'json'
      require 'securerandom'
      claude = File.join(Dir.home, '.claude')
      resume = ARGV.index('--resume')
      id = resume ? ARGV[resume + 1] : SecureRandom.uuid
      record = File.join(claude, 'sessions', "#{Process.pid}.json")
      FileUtils.mkdir_p([File.dirname(record), File.join(claude, 'projects', 'fake')])
      File.write(record, JSON.generate(pid: Process.pid, sessionId: id, cwd: Dir.pwd))
      File.write(File.join(claude, 'projects', 'fake', "#{id}.jsonl"), "{}\n")
      log = ENV.fetch('TEST_CLAUDE_LOG')
      File.open(log, 'a') { |file| file.puts JSON.generate(event: 'start', pid: Process.pid, cwd: Dir.pwd, args: ARGV, id: id) }
      # Real Claude takes about half a second to exit on TERM.
      trap('TERM') do
        Thread.new do
          sleep 0.4
          File.delete(record)
          File.open(log, 'a') { |file| file.puts JSON.generate(event: 'exit', pid: Process.pid) }
          exit
        end
      end
      sleep
    RUBY
    write_executable(File.join(fixture[:bin], 'claude'),
                     "#!/bin/bash\nexec -a claude #{Shellwords.join([RbConfig.ruby, script])} \"$@\"\n")
    log = File.join(fixture[:root], 'launches.jsonl')
    tmux = lambda do |*args|
      text, error, status = Open3.capture3('/usr/bin/tmux', '-S', socket, '-f', '/dev/null', *args)
      assert status.success?, error
      text.strip
    end
    events = -> { File.exist?(log) ? File.readlines(log).map { |line| JSON.parse(line) } : [] }
    wait_for = lambda do |count|
      300.times do
        break if events.call.length >= count
        sleep 0.01
      end
      events.call
    end
    begin
      tmux.call('new-session', '-d', '-s', 'test', '-c', project, '-x', '160', '-y', '50', '/bin/bash', '--noprofile', '--norc')
      pane = tmux.call('list-panes', '-t', 'test:0', '-F', '#{pane_id}')
      shell_pid = tmux.call('display-message', '-p', '-t', pane, '#{pane_pid}')
      environment = "export HOME=#{Shellwords.escape(fixture[:home])} PATH=#{Shellwords.escape(ENV.fetch('PATH'))} " \
                    "TEST_CLAUDE_LOG=#{Shellwords.escape(log)}"
      tmux.call('send-keys', '-t', pane, '-l', "#{environment}; claude --model opus 'first prompt'")
      tmux.call('send-keys', '-t', pane, 'Enter')
      equal 1, wait_for.call(1).length
      result = run_archon(%w[agents restart], 'TMUX' => "#{socket},1,0", 'TMUX_TMPDIR' => fixture[:root])
      equal 0, result[:status]
      assert result[:stdout].include?('Sent restart commands to 1/1 Claude panes.'), result.inspect
      first, exit_event, second = wait_for.call(3)
      equal %w[start exit start], [first, exit_event, second].map { |event| event && event['event'] }
      equal first['pid'], exit_event['pid']
      equal [project] * 2, [first['cwd'], second['cwd']]
      equal ['--resume', first['id'], '--model', 'opus'], second['args']
      equal shell_pid, tmux.call('display-message', '-p', '-t', pane, '#{pane_pid}')
    ensure
      system('/usr/bin/tmux', '-S', socket, 'kill-server', out: File::NULL, err: File::NULL)
    end
  end
end
