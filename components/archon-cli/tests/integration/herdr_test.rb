require_relative '../workspace_helpers'

test('real Herdr start revives stopped tools and kill clears saved sessions before a new selection') do
  fixture do |fixture|
    File.symlink('/usr/bin/herdr', File.join(fixture[:bin], 'herdr'))
    ENV['XDG_RUNTIME_DIR'] = File.join(fixture[:root], 'runtime')
    FileUtils.mkdir_p(ENV['XDG_RUNTIME_DIR'])
    config = File.join(ENV.fetch('XDG_CONFIG_HOME'), 'herdr')
    FileUtils.mkdir_p(config)
    File.write(File.join(config, 'config.toml'), "onboarding = false\n[terminal]\ndefault_shell = '/bin/bash'\n")
    %w[claude nvim].each do |tool|
      write_executable(File.join(fixture[:bin], tool), <<~'SH')
        #!/bin/sh
        printf '%s\n' "$0 $*" >> tool-starts
        exec sleep 60
      SH
    end
    projects = %w[cloned/old cloned/new].map { |relative| workspace_directory(fixture, relative) }
    context = { home: fixture[:home], environment: {}, tty: false }
    invoke = ->(session, arguments) { Archon::Herdr.request(session, arguments, Archon::Workspaces.method(:capture_command)) }
    wait_for_tools = lambda do |project, count = 2|
      Timeout.timeout(10) do
        path = File.join(project, 'tool-starts')
        sleep 0.05 until File.exist?(path) && File.readlines(path).length == count
        assert File.read(path).match?(%r{/claude $})
        assert File.read(path).include?('nvim .')
      end
    end
    begin
      status, _, error = capture { Archon::WorkspacesHerdr.run_workspaces_herdr(['start'], **context, picker: workspace_picker([projects.first])) }
      assert status == 0, "#{error}\n#{File.read(File.join(ENV.fetch('XDG_STATE_HOME'), 'archon/workspaces-herdr-server.log'))}"
      wait_for_tools.call(projects.first)
      before = invoke.call('archon', %w[workspace list]).fetch('workspaces').map { |item| item['workspace_id'] }
      equal 0, Archon::WorkspacesHerdr.run_workspaces_herdr(['stop'], **context)
      inside = context.merge(environment: { 'HERDR_ENV' => '1' }, picker: workspace_picker([projects.first]))
      equal 0, Archon::WorkspacesHerdr.run_workspaces_herdr(['start'], **inside)
      wait_for_tools.call(projects.first, 4)
      equal 0, Archon::WorkspacesHerdr.run_workspaces_herdr(['start'], **inside)
      equal before, invoke.call('archon', %w[workspace list]).fetch('workspaces').map { |item| item['workspace_id'] }
      # The saved ID finds a workspace renamed by hand and restores its folder label.
      invoke.call('archon', ['workspace', 'rename', before.first, 'renamed by hand'])
      equal 0, Archon::WorkspacesHerdr.run_workspaces_herdr(['start'], **inside)
      equal ['old'], invoke.call('archon', %w[workspace list]).fetch('workspaces').map { |item| item['label'] }
      tabs = invoke.call('archon', ['tab', 'list', '--workspace', before.first]).fetch('tabs')
      panes = invoke.call('archon', ['pane', 'list', '--workspace', before.first]).fetch('panes')
      process_info = lambda do |label|
        tab = tabs.find { |item| item['label'] == label }
        pane = panes.find { |item| item['tab_id'] == tab['tab_id'] }
        invoke.call('archon', ['pane', 'process-info', '--pane', pane['pane_id']]).fetch('process_info')
      end
      Timeout.timeout(10) { sleep 0.05 until Archon::Herdr.idle_shell?(process_info.call('shell')) }
      assert !Archon::Herdr.idle_shell?(process_info.call('nvim'))
      %w[default outside].each do |session|
        output = File.open(File.join(fixture[:root], "#{session}.log"), 'a')
        pid = Process.spawn('/usr/bin/herdr', '--session', session, 'server', in: File::NULL, out: output, err: output)
        Process.detach(pid)
        output.close
        Timeout.timeout(10) do
          sleep 0.05 until invoke.call('archon', %w[session list --json]).fetch('sessions').any? { |item| item['name'] == session && item['running'] }
        end
        invoke.call(session, ['workspace', 'create', '--cwd', projects.first, '--label', 'extra', '--no-focus'])
        invoke.call(session, ['session', 'stop', session, '--json'])
      end
      2.times { equal 0, Archon::WorkspacesHerdr.run_workspaces_herdr(['kill'], **context) }
      sessions = invoke.call('archon', %w[session list --json]).fetch('sessions')
      equal ['default'], sessions.map { |item| item['name'] }
      assert !sessions.first['running']
      assert !File.exist?(File.join(config, 'session.json'))
      assert File.exist?(File.join(config, 'config.toml'))
      2.times { equal 0, Archon::WorkspacesHerdr.run_workspaces_herdr(['start'], **context, picker: workspace_picker([projects.last])) }
      wait_for_tools.call(projects.last)
      workspaces = invoke.call('archon', %w[workspace list]).fetch('workspaces')
      equal ['new'], workspaces.map { |workspace| workspace['label'] }
      equal 4, File.readlines(File.join(projects.first, 'tool-starts')).length
    ensure
      %w[archon default outside].each do |session|
        Archon::Workspaces.capture_command('herdr', ['--session', session, 'session', 'stop', session, '--json'])
      end
    end
  end
end
