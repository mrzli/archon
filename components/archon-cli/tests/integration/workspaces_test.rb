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
        equal %w[nvim codex shell], result[:stdout].lines.map(&:strip)
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
