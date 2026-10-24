require_relative '../workspace_helpers'

test('real tmux project layouts are tagged, repeat safely, and stop preserves unrelated sessions') do
  fixture do |fixture|
    socket = File.join(fixture[:root], 'tmux.sock')
    invoke = lambda do |arguments|
      Archon::Shared.run_process('/usr/bin/tmux', ['-S', socket, '-f', '/dev/null', *arguments])
    end
    run = lambda do |_, arguments, **_|
      arguments = arguments.dup
      arguments[3] = 'sleep 60' if arguments.first == 'send-keys'
      invoke.call(arguments)[:status] || 1
    end
    capture = lambda do |_, arguments|
      result = invoke.call(arguments)
      { status: result[:status] || 1, output: "#{result[:stdout]}#{result[:stderr]}".rstrip }
    end
    projects = ['cloned/a.b', 'personal/owner/plain project'].map { |relative| workspace_directory(fixture, relative) }
    context = { home: fixture[:home], environment: {}, tty: false, run: run, capture: capture, picker: workspace_picker(projects) }
    begin
      2.times { equal 0, Archon::WorkspacesTmux.run_workspaces_tmux(['start'], **context) }
      definitions = Archon::WorkspacesTmux.project_definitions(projects)
      equal ['a-b', 'plain project'], definitions.map { |definition| definition[:session] }
      definitions.each do |definition|
        result = invoke.call(['list-windows', '-t', "=#{definition[:session]}", '-F', '#{window_name}'])
        equal 0, result[:status]
        equal %w[nvim lazygit shell claude], result[:stdout].lines.map(&:strip)
        result = invoke.call(['show-options', '-qv', '-t', "=#{definition[:session]}:", '@archon-managed'])
        equal 0, result[:status]
        equal '1', result[:stdout].strip
      end
      equal 0, invoke.call(['new-session', '-d', '-s', 'archon-unmanaged', 'sleep', '60'])[:status]
      FileUtils.rm_rf(File.join(fixture[:home], 'projects'))
      2.times { equal 0, Archon::WorkspacesTmux.run_workspaces_tmux(['stop'], **context) }
      equal "archon-unmanaged\n", invoke.call(['list-sessions', '-F', '#S'])[:stdout]
      equal 0, invoke.call(['kill-session', '-t', '=archon-unmanaged'])[:status]
      equal 0, Archon::WorkspacesTmux.run_workspaces_tmux(['stop'], **context)
    ensure
      invoke.call(['kill-server'])
    end
  end
end

test('real tmux restart from inside a session reattaches the terminal that started the workspaces') do
  fixture do |fixture|
    socket_dir = File.join(fixture[:root], 'tmux')
    FileUtils.mkdir_p(socket_dir, mode: 0o700)
    write_executable(File.join(fixture[:bin], 'tmux'), "#!/bin/sh\nexec /usr/bin/tmux -f /dev/null \"$@\"\n")
    %w[claude nvim].each { |tool| write_executable(File.join(fixture[:bin], tool), "#!/bin/sh\nexec sleep 60\n") }
    workspace_directory(fixture, 'cloned/project')
    environment = { 'TMUX_TMPDIR' => socket_dir }
    tmux = ->(*arguments) { Open3.capture3(environment, File.join(fixture[:bin], 'tmux'), *arguments).first.strip }
    marker = File.join(ENV.fetch('XDG_STATE_HOME'), 'archon/workspaces-tmux-restart.json')
    begin
      workspace_terminal(%w[w t start], environment: environment) do |terminal, wait, _|
        wait.call('Choose projects')
        terminal.write(" \r")
        Timeout.timeout(10) { sleep 0.05 until tmux.call('list-clients', '-F', '#S') == 'project' }
        tmux.call('set-option', '-t', '=project:', '@before-restart', '1')
        tmux.call('send-keys', '-t', '=project:shell', "#{RbConfig.ruby} #{ARCHON} w t restart", 'Enter')
        Timeout.timeout(30) do
          sleep 0.05 until File.exist?(marker) && JSON.parse(File.read(marker))['finished'] &&
                           tmux.call('list-clients', '-F', '#S') == 'project'
        end
        equal '', tmux.call('show-options', '-qv', '-t', '=project:', '@before-restart')
        tmux.call('kill-server')
      end
    ensure
      tmux.call('kill-server')
    end
  end
end
