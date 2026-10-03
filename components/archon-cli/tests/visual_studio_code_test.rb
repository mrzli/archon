require 'pty'
require 'timeout'
require_relative 'test_helpers'

VSC = Archon::VisualStudioCode

def vsc_repository(home, relative, worktree: false)
  path = File.join(home, 'projects', relative)
  FileUtils.mkdir_p(path)
  worktree ? File.write(File.join(path, '.git'), 'gitdir: /fixture') : FileUtils.mkdir_p(File.join(path, '.git'))
  path
end

def vsc_terminal(home)
  PTY.open do |master, slave|
    slave.winsize = [12, 90]
    script = <<~'RUBY'
      launch = ->(projects, workspace, run:) { File.write(File.join(Dir.home, 'launched.json'), JSON.generate([projects, workspace])) }
      exit Archon::VisualStudioCode.run_visual_studio_code(ARGV, launch: launch)
    RUBY
    pid = Process.spawn(RbConfig.ruby, '-r', File.expand_path('../lib/archon/cli', __dir__), '-e', script, 'start',
                        in: slave, out: slave, err: slave)
    transcript = ''
    read_until = lambda do |text|
      Timeout.timeout(5) do
        until transcript.include?(text)
          IO.select([master])
          transcript << master.read_nonblock(8192)
        end
      end
    end
    begin
      yield master, read_until, transcript
      _, status = Timeout.timeout(5) { Process.wait2(pid) }
      assert slave.echo?, 'terminal echo was not restored'
      while IO.select([master], nil, nil, 0.01)
        transcript << master.read_nonblock(8192)
      end
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

def vsc_hyprland(automatic: true, fail_group: false, launch_failure: nil)
  calls = []
  clients = [{ 'address' => '0xmanual', 'class' => 'Code', 'grouped' => [], 'workspace' => { 'id' => 3 }, 'at' => [0, 0] }]
  workspace, focused, count = 3, nil, 0
  run = lambda do |command, arguments|
    calls << [command, arguments]
    output, status = 'ok', 0
    if command == 'code'
      equal '--new-window', arguments.first
      count += 1
      if count == launch_failure
        status = 1
      else
        client = { 'address' => "0x#{count}", 'class' => 'Code', 'grouped' => [], 'workspace' => { 'id' => workspace }, 'at' => [100, 0] }
        target = clients.find { |window| window['address'] == focused }
        if automatic && target && !target['grouped'].empty?
          group = target['grouped'] + [client['address']]
          clients.select { |window| target['grouped'].include?(window['address']) }.each { |window| window['grouped'] = group }
          client['grouped'] = group
        end
        clients << client
        focused = client['address']
      end
    elsif command == 'hyprctl'
      if arguments == %w[-j activeworkspace]
        output = JSON.generate({ 'id' => workspace })
      elsif arguments == %w[-j clients]
        output = JSON.generate(clients)
      else
        equal 'dispatch', arguments.first
        equal 2, arguments.length
        match = /\Ahl\.dsp\.([\w.]+)\(\{ (.*) \}\)\z/.match(arguments.last)
        assert match, "Expected Lua dispatcher: #{arguments.last}"
        dispatcher = match[1]
        fields = match[2].scan(/(\w+) = ("[^"]*"|true|false)/).to_h.transform_values { |value| JSON.parse(value) }
        client = clients.find { |window| window['address'] == focused }
        case dispatcher
        when 'focus'
          fields.key?('workspace') ? workspace = fields['workspace'] : focused = fields.fetch('window').delete_prefix('address:')
        when 'window.float' then equal 'disable', fields.fetch('action')
        when 'group.toggle' then client['grouped'] = [focused]
        when 'window.move'
          if fields.key?('workspace')
            equal false, fields.fetch('follow')
            destination = fields.fetch('workspace')
            address = fields.fetch('window').delete_prefix('address:')
            moved = clients.find { |window| window['address'] == address }
            group = moved['grouped'].empty? ? [address] : moved['grouped']
            clients.select { |window| group.include?(window['address']) }.each { |window| window['workspace'] = { 'id' => destination } }
          elsif fields.key?('into_group') && !fail_group
            target = clients.find { |window| !window['grouped'].empty? }
            group = target['grouped'] + [focused]
            clients.select { |window| group.include?(window['address']) }.each { |window| window['grouped'] = group }
          end
        else raise "Unexpected dispatcher: #{dispatcher}"
        end
      end
    else
      raise "Unexpected process: #{command}"
    end
    { stdout: output, stderr: '', status: status }
  end
  { run: run, calls: calls, clients: clients }
end

test('VS Code discovery lists sorted repository roots and worktrees without traversing repositories or symlinks') do
  fixture do |fixture|
    home = fixture[:home]
    equal [], VSC.discover_projects(home)
    expected = %w[cloned/z cloned/owner/deep/a personal/owner/deep/a personal/owner/space\ project].map { |path| vsc_repository(home, path) }
    expected << vsc_repository(home, 'personal/worktree', worktree: true)
    vsc_repository(home, 'personal/owner/deep/a/vendor/nested')
    FileUtils.mkdir_p(File.join(home, 'projects/personal/non-git'))
    File.symlink(File.join(home, 'projects/personal'), File.join(home, 'projects/cloned/link'))
    equal expected.sort, VSC.discover_projects(home)
  end
end

test('VS Code CLI validates arguments and routes aliases and help without external effects') do
  fixture do |fixture|
    %w[hyprctl code pkill].each { |name| write_executable(File.join(fixture[:bin], name), "#!/bin/sh\nexit 99\n") }
    %w[help -h --help].each do |help|
      equal 0, run_archon(['vsc', help])[:status]
      equal run_archon(['visual-studio-code', help]), run_archon(['vsc', help])
    end
    [%w[vsc], %w[vsc kill], %w[vsc start extra], %w[vsc stop extra], %w[vsc help extra]].each do |args|
      equal 2, run_archon(args)[:status]
    end
    equal 0, run_archon(%w[vsc start])[:status]
    assert !File.exist?(File.join(fixture[:home], '.local/state/archon'))
    vsc_repository(fixture[:home], 'personal/a')
    result = run_archon(['vsc'])
    equal 2, result[:status]
    assert result[:stderr].include?(VSC::HELP)
    assert !File.exist?(File.join(fixture[:home], '.local/state/archon'))
    result = run_archon(%w[vsc start])
    equal 1, result[:status]
    assert result[:stderr].include?('interactive terminal')
  end
end

test('terminal navigation, toggling, saved defaults, scrolling, and launch order') do
  fixture do |fixture|
    home = fixture[:home]
    projects = (1..12).map { |number| vsc_repository(home, "personal/owner/project-#{number.to_s.rjust(2, '0')}") }
    status, transcript = vsc_terminal(home) do |terminal, wait, _|
      wait.call('Choose workspace')
      terminal.write("0\r")
      wait.call('Choose projects')
      terminal.write("j \e[A \e[B k \e[B \r")
    end
    equal 0, status
    assert transcript.include?('Space: toggle') && transcript.include?('Esc / Ctrl+C: cancel')
    expected = { 'workspace' => 10, 'projects' => [projects[1]] }
    state_path = File.join(home, '.local/state/archon/visual-studio-code.json')
    equal expected, JSON.parse(File.read(state_path))
    equal [[projects[1]], 10], JSON.parse(File.read(File.join(home, 'launched.json')))
    equal 0o600, File.stat(state_path).mode & 0o777

    status, = vsc_terminal(home) do |terminal, wait, text|
      wait.call('Choose workspace')
      assert text.include?('(*) 10')
      terminal.write("\r")
      wait.call('Choose projects')
      assert text.include?('[x] personal/owner/project-02')
      terminal.write("k " + 'j' * 11 + " \r")
    end
    equal 0, status
    equal [[projects[0], projects[1], projects[11]], 10], JSON.parse(File.read(File.join(home, 'launched.json')))
  end
end

test('Escape at either prompt and Ctrl+C cancel the entire execution and restore the terminal') do
  fixture do |fixture|
    home = fixture[:home]
    project = vsc_repository(home, 'cloned/a')
    path = File.join(home, '.local/state/archon/visual-studio-code.json')
    VSC.save_selection(path, { 'workspace' => 4, 'projects' => [project] })
    before = File.read(path)
    [['Choose workspace', "\e", 0], ['Choose projects', "\e", 0], ['Choose projects', "\u0003", 130]].each do |prompt, key, expected_status|
      status, text = vsc_terminal(home) do |terminal, wait, _|
        wait.call('Choose workspace')
        if prompt == 'Choose projects'
          terminal.write("2\r")
          wait.call(prompt)
        end
        terminal.write(key)
      end
      equal expected_status, status
      assert text.include?('Cancelled.')
      equal before, File.read(path)
      assert !File.exist?(File.join(home, 'launched.json'))
    end
  end
end

test('empty selection is saved and stale projects are not reopened') do
  fixture do |fixture|
    home = fixture[:home]
    project = vsc_repository(home, 'cloned/a')
    path = File.join(home, '.local/state/archon/visual-studio-code.json')
    VSC.save_selection(path, { 'workspace' => 2, 'projects' => [File.join(home, 'deleted')] })
    status, = vsc_terminal(home) do |terminal, wait, text|
      wait.call('Choose workspace')
      terminal.write("\r")
      wait.call('Choose projects')
      assert text.include?('[ ] cloned/a')
      terminal.write("\r")
    end
    equal 0, status
    equal({ 'workspace' => 2, 'projects' => [] }, VSC.load_selection(path))
    assert !File.exist?(File.join(home, 'launched.json'))
    File.write(path, '{broken')
    equal 1, run_archon(%w[vsc start])[:status]
    equal '{broken', File.read(path)
  end
end

[true, false].each do |automatic|
  test("launch groups new windows in order and preserves existing windows, automatic grouping: #{automatic}") do
    backend = vsc_hyprland(automatic: automatic)
    projects = ['/fixture/one space', '/fixture/two', '/fixture/three']
    VSC.launch_projects(projects, 10, run: backend[:run])
    equal projects.map { |path| ['code', ['--new-window', path]] }, backend[:calls].select { |command, _| command == 'code' }
    backend[:clients].drop(1).each do |client|
      equal %w[0x1 0x2 0x3], client['grouped']
      equal({ 'id' => '10' }, client['workspace'])
    end
    equal({ 'id' => 3 }, backend[:clients].first['workspace'])
    equal [], backend[:clients].first['grouped']
    equal ['hyprctl', ['dispatch', 'hl.dsp.focus({ window = "address:0x1" })']], backend[:calls].last
  end
end

test('launch and grouping failures move opened windows to the target workspace') do
  [{ launch_failure: 2 }, { automatic: false, fail_group: true }].each do |options|
    backend = vsc_hyprland(**options)
    raises(/failed|could not group/) { VSC.launch_projects(['/one', '/two'], 5, run: backend[:run]) }
    backend[:clients].drop(1).each { |client| equal({ 'id' => '5' }, client['workspace']) }
    equal ['hyprctl', ['dispatch', 'hl.dsp.focus({ workspace = "5" })']], backend[:calls].last
  end
  backend = vsc_hyprland(launch_failure: 1)
  raises(/failed/) { VSC.launch_projects(['/one'], 5, run: backend[:run]) }
  equal ['hyprctl', ['dispatch', 'hl.dsp.focus({ workspace = "3" })']], backend[:calls].last
end

test('launch timeout and Hyprland dispatcher rejection are reported') do
  calls = []
  run = lambda do |command, arguments|
    calls << [command, arguments]
    output = arguments == %w[-j clients] ? '[]' : (arguments == %w[-j activeworkspace] ? '{"id":2}' : 'ok')
    { stdout: output, stderr: '', status: 0 }
  end
  raises(/Timed out/) { VSC.launch_projects(['/one'], 8, run: run, timeout: 0) }
  equal ['hyprctl', ['dispatch', 'hl.dsp.focus({ workspace = "2" })']], calls.last
  rejected = ->(*_) { { stdout: 'Invalid dispatcher', stderr: '', status: 0 } }
  raises(/Invalid dispatcher/) { VSC.hypr_dispatch(rejected, 'group.toggle') }
  lua_rejection = ->(*_) { { stdout: 'error: hl.dispatch: expected a dispatcher', stderr: '', status: 7 } }
  raises(/hyprctl dispatch .*failed \(7\): error: hl.dispatch: expected a dispatcher/) do
    VSC.hypr_dispatch(lua_rejection, 'focus', workspace: '1')
  end
end

test('stop requests normal closure of every Code window, preserves other apps, and succeeds repeatedly') do
  fixture do |fixture|
    state_path = File.join(fixture[:home], 'clients.json')
    windows = [{ 'class' => 'Code', 'address' => '0x1' }, { 'class' => 'code', 'address' => '0x2' },
               { 'class' => 'code-helper', 'address' => '0x3' }, { 'class' => 'terminal', 'address' => '0x4' }]
    File.write(state_path, JSON.generate(windows))
    write_executable(File.join(fixture[:bin], 'hyprctl'), <<~'RUBY')
      #!/usr/bin/env ruby
      require 'json'
      path = File.join(Dir.home, 'clients.json')
      windows = JSON.parse(File.read(path))
      File.open(File.join(Dir.home, 'hyprctl-calls'), 'a') { |file| file.puts(JSON.generate(ARGV)) }
      if ARGV == %w[-j clients]
        puts JSON.generate(windows)
      elsif ARGV.first == 'dispatch' && (match = /\Ahl\.dsp\.window\.close\(\{ window = "address:(0x[0-9a-f]+)" \}\)\z/.match(ARGV.last))
        windows.reject! { |window| window.fetch('address') == match[1] }
        File.write(path, JSON.generate(windows))
        puts 'ok'
      else
        exit 99
      end
    RUBY
    write_executable(File.join(fixture[:bin], 'pkill'), "#!/bin/sh\nexit 99\n")
    result = run_archon(%w[vsc stop])
    equal 0, result[:status]
    assert result[:stdout].include?('Closed all VS Code windows.')
    equal windows.drop(2), JSON.parse(File.read(state_path))
    calls = File.readlines(File.join(fixture[:home], 'hyprctl-calls')).map { |line| JSON.parse(line) }
    equal [%w[-j clients], ['dispatch', 'hl.dsp.window.close({ window = "address:0x1" })'], ['dispatch', 'hl.dsp.window.close({ window = "address:0x2" })'], %w[-j clients]], calls
    result = run_archon(%w[vsc stop])
    equal 0, result[:status]
    assert result[:stdout].include?('No VS Code windows running.')
    assert !File.exist?(File.join(fixture[:home], '.local/state/archon'))
  end
end

test('stop waits for windows to disappear and does not force termination on a shutdown veto or failure') do
  calls = []
  listings = 0
  run = lambda do |command, arguments|
    equal 'hyprctl', command
    calls << arguments
    if arguments == %w[-j clients]
      listings += 1
      output = JSON.generate(listings < 3 ? [{ 'class' => 'Code', 'address' => '0x1' }] : [])
    else
      equal ['dispatch', 'hl.dsp.window.close({ window = "address:0x1" })'], arguments
      output = 'ok'
    end
    { stdout: output, stderr: '', status: 0 }
  end
  equal 1, VSC.stop_windows(run: run)
  equal 3, listings

  stuck = lambda do |command, arguments|
    equal 'hyprctl', command
    output = arguments == %w[-j clients] ? '[{"class":"Code","address":"0x1"}]' : 'ok'
    { stdout: output, stderr: '', status: 0 }
  end
  raises(/did not finish closing/) { VSC.stop_windows(run: stuck, timeout: 0) }
  failed = ->(*_) { { stdout: '', stderr: 'disconnected', status: 1 } }
  status, output, error = capture { VSC.run_visual_studio_code(['stop'], run: failed) }
  equal 1, status
  assert !output.include?('Closed')
  assert error.include?('disconnected')
end
