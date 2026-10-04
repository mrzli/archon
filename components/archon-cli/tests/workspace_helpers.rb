require 'pty'
require 'timeout'
require_relative 'test_helpers'

# Every project fixture is a plain directory, with no Git metadata.
def workspace_directory(fixture, relative = 'personal/owner/project')
  path = File.join(fixture[:home], 'projects', relative)
  FileUtils.mkdir_p(path)
  path
end

def workspace_picker(paths)
  ->(*_, **_) { { 'projects' => paths } }
end

def workspace_terminal(arguments, executable: ARCHON, environment: {})
  PTY.open do |master, slave|
    slave.winsize = [14, 100]
    pid = Process.spawn(environment, RbConfig.ruby, executable, *arguments, in: slave, out: slave, err: slave)
    transcript = ''
    wait = lambda do |text|
      Timeout.timeout(10) do
        until transcript.include?(text)
          IO.select([master])
          transcript << master.read_nonblock(16384)
        end
      end
    end
    begin
      yield master, wait, transcript
      _, status = Timeout.timeout(10) { Process.wait2(pid) }
      assert slave.echo?, 'terminal echo was not restored'
      [status.exitstatus, transcript]
    ensure
      begin
        Process.kill('KILL', pid)
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
  end
end
