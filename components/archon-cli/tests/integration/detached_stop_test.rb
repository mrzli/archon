require_relative '../workspace_helpers'

test('workspace stop survives closing its calling pane and preserves unrelated sessions') do
  fixture do |fixture|
    socket = File.join(fixture[:root], 'tmux.sock')
    File.symlink('/usr/bin/tmux', File.join(fixture[:bin], 'tmux'))
    tmux = lambda do |*arguments|
      output, error, status = Open3.capture3('/usr/bin/tmux', '-S', socket, '-f', '/dev/null', *arguments)
      assert status.success?, error
      output.strip
    end
    projects = %w[cloned/one personal/owner/two personal/owner/three].map { |relative| workspace_directory(fixture, relative) }
    names = Archon::Workspaces.project_definitions(projects).map { |definition| definition[:session] }
    begin
      [*names, 'unrelated'].each { |name| tmux.call('new-session', '-d', '-s', name, 'sleep', '60') }
      names.each { |name| tmux.call('set-option', '-t', "=#{name}:", '@archon-managed', '1') }
      FileUtils.rm_rf(File.join(fixture[:home], 'projects'))
      tmux.call('new-window', '-t', "=#{names.first}", '-n', 'stopper', '/usr/bin/env',
        "HOME=#{fixture[:home]}", "XDG_STATE_HOME=#{ENV.fetch('XDG_STATE_HOME')}", "PATH=#{ENV.fetch('PATH')}",
        RbConfig.ruby, File.expand_path('../../bin/arc', __dir__), 'w', 't', 'stop')
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      loop do
        sessions = tmux.call('list-sessions', '-F', '#S').lines.map(&:strip).sort
        break if sessions == ['unrelated']
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          log = File.join(ENV.fetch('XDG_STATE_HOME'), 'archon/workspaces-tmux-stop.log')
          warn File.read(log) if File.exist?(log)
          equal ['unrelated'], sessions
        end
        sleep 0.05
      end
    ensure
      system('/usr/bin/tmux', '-S', socket, 'kill-server', out: File::NULL, err: File::NULL)
    end
  end
end

test('tmux kill from its own pane shuts down unrelated sessions on the same server and preserves other servers') do
  fixture do |fixture|
    socket = File.join(fixture[:root], 'tmux.sock')
    other_socket = File.join(fixture[:root], 'other.sock')
    File.symlink('/usr/bin/tmux', File.join(fixture[:bin], 'tmux'))
    invoke = lambda do |target, *arguments|
      output, error, status = Open3.capture3('/usr/bin/tmux', '-S', target, '-f', '/dev/null', *arguments)
      { status: status.exitstatus, output: "#{output}#{error}" }
    end
    begin
      %w[calling unrelated].each { |name| equal 0, invoke.call(socket, 'new-session', '-d', '-s', name, 'sleep', '60')[:status] }
      equal 0, invoke.call(other_socket, 'new-session', '-d', '-s', 'elsewhere', 'sleep', '60')[:status]
      equal 0, invoke.call(socket, 'new-window', '-t', '=calling', '-n', 'killer', '/usr/bin/env',
        "HOME=#{fixture[:home]}", "XDG_STATE_HOME=#{ENV.fetch('XDG_STATE_HOME')}", "PATH=#{ENV.fetch('PATH')}",
        RbConfig.ruby, File.expand_path('../../bin/arc', __dir__), 'w', 't', 'kill')[:status]
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      loop do
        result = invoke.call(socket, 'list-sessions')
        break if result[:status] != 0 && Archon::WorkspacesTmux.absent_server?(result[:output])
        assert Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline, result.inspect
        sleep 0.05
      end
      equal "elsewhere\n", invoke.call(other_socket, 'list-sessions', '-F', '#S')[:output]
      capture = ->(_, args) { invoke.call(socket, *args) }
      equal 0, Archon::WorkspacesTmux.run_workspaces_tmux(['kill'], environment: {}, capture: capture)
    ensure
      invoke.call(socket, 'kill-server')
      invoke.call(other_socket, 'kill-server')
    end
  end
end
