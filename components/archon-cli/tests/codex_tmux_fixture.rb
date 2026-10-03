require_relative 'test_helpers'

def with_codex_tmux
  fixture do |fixture|
    socket = File.join(fixture[:root], 'codex.sock')
    project = File.join(fixture[:root], 'project with spaces')
    FileUtils.mkdir_p(project)
    File.symlink('/usr/bin/tmux', File.join(fixture[:bin], 'tmux'))
    write_executable(File.join(fixture[:bin], 'herdr'), "#!/bin/sh\nprintf '%s\\n' '{\"sessions\":[]}'\n")
    script = File.join(fixture[:root], 'fake_codex.rb')
    File.write(script, <<~'RUBY')
      require 'json'
      $stdout.sync = true
      trap('INT') { exit }
      sleep ENV.fetch('TEST_CODEX_STARTUP_DELAY', '0').to_f if ARGV.include?('resume')
      File.open(ENV.fetch('TEST_CODEX_LOG'), 'a') { |file| file.puts JSON.generate(pid: Process.pid, cwd: Dir.pwd, args: ARGV) }
      puts '? for shortcuts'
      while (line = $stdin.gets)
        exit if line.strip == '/quit'
      end
    RUBY
    write_executable(File.join(fixture[:bin], 'codex'), "#!/bin/bash\nexec -a codex #{Shellwords.join([RbConfig.ruby, script])} \"$@\"\n")
    log = File.join(fixture[:root], 'launches.jsonl')
    tmux = lambda do |*args|
      text, error, status = Open3.capture3('/usr/bin/tmux', '-S', socket, '-f', '/dev/null', *args)
      assert status.success?, error
      text.strip
    end
    command = "export PATH=#{Shellwords.escape(ENV.fetch('PATH'))} TEST_CODEX_LOG=#{Shellwords.escape(log)}; codex -m test-model"
    begin
      tmux.call('new-session', '-d', '-s', 'test', '-c', project, '-x', '160', '-y', '50', '/bin/bash', '--noprofile', '--norc')
      yield fixture, tmux, project, log, command
    ensure
      system('/usr/bin/tmux', '-S', socket, 'kill-server', out: File::NULL, err: File::NULL)
    end
  end
end
