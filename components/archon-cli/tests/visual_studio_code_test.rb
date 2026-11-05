require 'pty'
require 'timeout'
require_relative 'test_helpers'

VSC = Archon::VisualStudioCode

def vsc_project(home, relative)
  path = File.join(home, 'projects', relative)
  FileUtils.mkdir_p(path)
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

# Models what the code relies on from Omarchy's undocumented o.workspaces.move_window.
# The focused monitor owns the given block of ten global workspace numbers, and
# `helpers` selects how it behaves: :working, :missing (Hyprland reports the Lua
# error), :silent (ok without moving, as with no active window), :skips_first (silent
# for window 0x1 only), or :other_block (each move lands one monitor further along).
# The temporary named workspace has a negative id, as Hyprland gives named workspaces.
# Focusing a window makes its monitor the focused one. `focus_elsewhere_at` moves
# focus to another monitor as the given window opens, and `closes_first_at` closes
# window 0x1 then.
def vsc_hyprland(automatic: true, fail_group: false, launch_failure: nil, block: 0, helpers: :working,
                 focus_elsewhere_at: nil, closes_first_at: nil)
  calls = []
  clients = [{ 'address' => '0xmanual', 'class' => 'com.microsoft.VSCode', 'grouped' => [], 'workspace' => { 'id' => 3 }, 'at' => [0, 0] }]
  staging_id = -99
  staging_block = nil
  moves = 0
  workspace, focused, count = 3, nil, 0
  move_group = lambda do |address, destination|
    moved = clients.find { |window| window['address'] == address }
    group = moved['grouped'].empty? ? [address] : moved['grouped']
    clients.select { |window| group.include?(window['address']) }.each { |window| window['workspace'] = { 'id' => destination } }
  end
  move_window = lambda do |slot|
    assert (1..10).include?(slot), "Slot outside 1-10: #{slot}"
    next if helpers == :skips_first && focused == '0x1'

    move_group.call(focused, block * 10 + slot + 10 * moves)
    moves += 1 if helpers == :other_block
  end
  run = lambda do |command, arguments|
    calls << [command, arguments]
    output, status = 'ok', 0
    if command == 'code'
      equal '--new-window', arguments.first
      count += 1
      block += 4 if count == focus_elsewhere_at
      clients.reject! { |window| window['address'] == '0x1' } if count == closes_first_at
      if count == launch_failure
        status = 1
      else
        client = { 'address' => "0x#{count}", 'class' => 'com.microsoft.VSCode', 'grouped' => [], 'workspace' => { 'id' => workspace }, 'at' => [100, 0] }
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
        if (omarchy = /\Ao\.workspaces\.move_window\((\d+), false\)\z/.match(arguments.last))
          if helpers == :missing
            output, status = "error: attempt to index a nil value (global 'o')", 7
          elsif helpers != :silent
            move_window.call(omarchy[1].to_i)
          end
        else
          match = /\Ahl\.dsp\.([\w.]+)\(\{ (.*) \}\)\z/.match(arguments.last)
          assert match, "Expected Lua dispatcher: #{arguments.last}"
          dispatcher = match[1]
          fields = match[2].scan(/(\w+) = ("[^"]*"|true|false)/).to_h.transform_values { |value| JSON.parse(value) }
          client = clients.find { |window| window['address'] == focused }
          case dispatcher
          when 'focus'
            if fields.key?('workspace')
              staging_block ||= block if fields['workspace'].start_with?('name:')
              workspace = fields['workspace'].start_with?('name:') ? staging_id : Integer(fields['workspace'])
            else
              address = fields.fetch('window').delete_prefix('address:')
              window = clients.find { |candidate| candidate['address'] == address }
              if window
                focused = address
                workspace = window['workspace']['id']
                block = workspace.negative? ? staging_block : (workspace - 1) / 10
              else
                output, status = 'error: window not found', 7
              end
            end
          when 'window.float' then equal 'disable', fields.fetch('action')
          when 'group.toggle' then client['grouped'] = [focused]
          when 'window.move'
            if fields.key?('workspace')
              equal false, fields.fetch('follow')
              assert fields.fetch('workspace').start_with?('name:archon-vsc-'), "Global workspace move: #{arguments.last}"
              move_group.call(fields.fetch('window').delete_prefix('address:'), staging_id)
            elsif fields.key?('into_group') && !fail_group
              target = clients.find { |window| !window['grouped'].empty? }
              group = target['grouped'] + [focused]
              clients.select { |window| group.include?(window['address']) }.each { |window| window['grouped'] = group }
            end
          else raise "Unexpected dispatcher: #{dispatcher}"
          end
        end
      end
    else
      raise "Unexpected process: #{command}"
    end
    { stdout: output, stderr: '', status: status }
  end
  { run: run, calls: calls, clients: clients }
end

test('VS Code discovery uses exact directory depths without requiring Git or following symlinks') do
  fixture do |fixture|
    home = fixture[:home]
    equal [], Archon::WorkspaceProjects.discover_projects(home)
    expected = %w[cloned/z cloned/.hidden cloned/owner personal/owner/a personal/owner/space\ project].map do |relative|
      path = File.join(home, 'projects', relative)
      FileUtils.mkdir_p(path)
      path
    end
    vsc_project(home, 'cloned/owner/deep/nested')
    vsc_project(home, 'personal/owner/a/vendor/nested')
    FileUtils.mkdir_p(File.join(home, 'projects/personal/empty-owner'))
    File.write(File.join(home, 'projects/cloned/file'), '')
    File.symlink(expected.first, File.join(home, 'projects/cloned/link'))
    File.symlink(File.join(home, 'projects/personal/owner'), File.join(home, 'projects/personal/linked-owner'))
    File.symlink(expected.first, File.join(home, 'projects/personal/owner/link'))
    equal expected.sort, Archon::WorkspaceProjects.discover_projects(home)
  end
end

test('VS Code CLI validates arguments and routes aliases and help without external effects') do
  fixture do |fixture|
    %w[hyprctl code pkill].each { |name| write_executable(File.join(fixture[:bin], name), "#!/bin/sh\nexit 99\n") }
    %w[help -h --help].each do |help|
      equal 0, run_archon(['w', 'vsc', help])[:status]
      equal run_archon(['workspaces', 'visual-studio-code', help]), run_archon(['w', 'vsc', help])
    end
    [%w[vsc], %w[vsc kill], %w[vsc start extra], %w[vsc stop extra], %w[vsc help extra]].each do |args|
      equal 2, run_archon(['w', *args])[:status]
    end
    equal 0, run_archon(%w[w vsc start])[:status]
    assert !File.exist?(File.join(fixture[:home], '.local/state/archon'))
    vsc_project(fixture[:home], 'personal/owner/a')
    result = run_archon(%w[w vsc])
    equal 2, result[:status]
    assert result[:stderr].include?(VSC::HELP)
    assert !File.exist?(File.join(fixture[:home], '.local/state/archon'))
    result = run_archon(%w[w vsc start])
    equal 1, result[:status]
    assert result[:stderr].include?('interactive terminal')
  end
end

test('terminal navigation, toggling, saved defaults, scrolling, and launch order') do
  fixture do |fixture|
    home = fixture[:home]
    projects = (1..12).map { |number| vsc_project(home, "personal/owner/project-#{number.to_s.rjust(2, '0')}") }
    status, transcript = vsc_terminal(home) do |terminal, wait, _|
      wait.call('Choose workspace')
      terminal.write("0\r")
      wait.call('Choose projects')
      terminal.write("j \e[A \e[B k \e[B \r")
    end
    equal 0, status
    assert transcript.include?('Space: toggle') && transcript.include?('Esc / Ctrl+C: cancel')
    expected = { 'workspace' => 10, 'projects' => [projects[1]] }
    state_path = File.join(home, '.local/state/archon/workspaces/visual-studio-code.json')
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
    project = vsc_project(home, 'cloned/a')
    path = File.join(home, '.local/state/archon/workspaces/visual-studio-code.json')
    Archon::WorkspaceProjects.save_selection(path, { 'workspace' => 4, 'projects' => [project] })
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
    project = vsc_project(home, 'cloned/a')
    path = File.join(home, '.local/state/archon/workspaces/visual-studio-code.json')
    Archon::WorkspaceProjects.save_selection(path, { 'workspace' => 2, 'projects' => [File.join(home, 'deleted')] })
    status, = vsc_terminal(home) do |terminal, wait, text|
      wait.call('Choose workspace')
      terminal.write("\r")
      wait.call('Choose projects')
      assert text.include?('[ ] cloned/a')
      terminal.write("\r")
    end
    equal 0, status
    equal({ 'workspace' => 2, 'projects' => [] }, Archon::WorkspaceProjects.load_selection(path, workspace: true))
    assert !File.exist?(File.join(home, 'launched.json'))
    File.write(path, '{broken')
    equal 1, run_archon(%w[w vsc start])[:status]
    equal '{broken', File.read(path)
  end
end

[true, false].each do |automatic|
  test("launch groups new windows in order and preserves existing windows, automatic grouping: #{automatic}") do
    backend = vsc_hyprland(automatic: automatic)
    projects = ['/fixture/one space', '/fixture/two', '/fixture/three']
    VSC.launch_projects(projects, 10, run: backend[:run], timeout: 0)
    equal projects.map { |path| ['code', ['--new-window', path]] }, backend[:calls].select { |command, _| command == 'code' }
    backend[:clients].drop(1).each do |client|
      equal %w[0x1 0x2 0x3], client['grouped']
      equal({ 'id' => 10 }, client['workspace'])
    end
    equal({ 'id' => 3 }, backend[:clients].first['workspace'])
    equal [], backend[:clients].first['grouped']
    equal ['hyprctl', ['dispatch', 'hl.dsp.focus({ window = "address:0x1" })']], backend[:calls].last
  end
end

test('the digit is a slot of the focused monitor, reached through the Omarchy helper') do
  [[3, 13], [10, 20]].each do |slot, id|
    backend = vsc_hyprland(block: 1)
    VSC.launch_projects(['/one', '/two'], slot, run: backend[:run], timeout: 0)
    backend[:clients].drop(1).each { |client| equal({ 'id' => id }, client['workspace']) }
    equal({ 'id' => 3 }, backend[:clients].first['workspace'])
    assert backend[:calls].include?(['hyprctl', ['dispatch', "o.workspaces.move_window(#{slot}, false)"]])
    equal ['hyprctl', ['dispatch', 'hl.dsp.focus({ window = "address:0x1" })']], backend[:calls].last
  end
end

test('launch and grouping failures move opened windows to the target workspace') do
  [{ launch_failure: 2 }, { automatic: false, fail_group: true }].each do |options|
    backend = vsc_hyprland(block: 1, **options)
    raises(/failed|could not group/) { VSC.launch_projects(['/one', '/two'], 5, run: backend[:run]) }
    backend[:clients].drop(1).each { |client| equal({ 'id' => 15 }, client['workspace']) }
    equal ['hyprctl', ['dispatch', 'hl.dsp.focus({ window = "address:0x1" })']], backend[:calls].last
  end
  backend = vsc_hyprland(launch_failure: 1)
  raises(/failed/) { VSC.launch_projects(['/one'], 5, run: backend[:run]) }
  equal ['hyprctl', ['dispatch', 'hl.dsp.focus({ workspace = "3" })']], backend[:calls].last
end

test('an Omarchy helper that fails or does not move the window raises without using global numbers') do
  { missing: /o\.workspaces\.move_window\(5, false\) failed \(7\): error: /,
    silent: /did not move VS Code window 0x1 to slot 5; it is on workspace -99/ }.each do |helpers, message|
    backend = vsc_hyprland(helpers: helpers)
    raises(message) { VSC.launch_projects(['/one'], 5, run: backend[:run], timeout: 0) }

    backend = vsc_hyprland(helpers: helpers, launch_failure: 2)
    _, _, error = capture do
      raises(/code --new-window \/two failed/) { VSC.launch_projects(['/one', '/two'], 5, run: backend[:run], timeout: 0) }
    end
    assert error.match?(message), error
    assert error.include?('Could not restore VS Code windows'), error
  end

  backend = vsc_hyprland(automatic: false, fail_group: true, helpers: :other_block)
  _, _, error = capture do
    raises(/could not group/) { VSC.launch_projects(['/one', '/two'], 5, run: backend[:run], timeout: 0) }
  end
  assert error.include?('window 0x2 to slot 5; it is on workspace 15'), error
end

test('windows go to the monitor that holds them when focus moved to another monitor during the launch') do
  backend = vsc_hyprland(block: 1, focus_elsewhere_at: 2, launch_failure: 2)
  raises(/failed/) { VSC.launch_projects(['/one', '/two'], 3, run: backend[:run], timeout: 0) }
  equal({ 'id' => 13 }, backend[:clients].last['workspace'])
end

test('cleanup moves the remaining windows past a closed window and a window that fails') do
  backend = vsc_hyprland(block: 1, automatic: false, fail_group: true, closes_first_at: 2)
  _, _, error = capture do
    raises(/./) { VSC.launch_projects(['/one', '/two'], 5, run: backend[:run], timeout: 0) }
  end
  equal ['0xmanual', '0x2'], backend[:clients].map { |client| client['address'] }
  equal({ 'id' => 15 }, backend[:clients].last['workspace'])
  equal ['hyprctl', ['dispatch', 'hl.dsp.focus({ window = "address:0x2" })']], backend[:calls].last
  assert !error.include?('Could not restore'), error

  backend = vsc_hyprland(launch_failure: 2, closes_first_at: 2)
  raises(/failed/) { VSC.launch_projects(['/one', '/two'], 5, run: backend[:run], timeout: 0) }
  equal ['hyprctl', ['dispatch', 'hl.dsp.focus({ workspace = "3" })']], backend[:calls].last

  backend = vsc_hyprland(block: 1, automatic: false, fail_group: true, helpers: :skips_first)
  _, _, error = capture do
    raises(/could not group/) { VSC.launch_projects(['/one', '/two'], 5, run: backend[:run], timeout: 0) }
  end
  equal({ 'id' => -99 }, backend[:clients][1]['workspace'])
  equal({ 'id' => 15 }, backend[:clients][2]['workspace'])
  assert error.include?('did not move VS Code window 0x1'), error
end

test('a failed window cleanup is reported without hiding the launch failure') do
  run = lambda do |_, arguments|
    output = arguments == %w[-j clients] ? '[]' : (arguments == %w[-j activeworkspace] ? '{"id":2}' : 'ok')
    output = 'Invalid dispatcher' if arguments.last == 'hl.dsp.focus({ workspace = "2" })'
    { stdout: output, stderr: '', status: 0 }
  end
  _, _, error = capture do
    raises(/Timed out waiting for VS Code/) { VSC.launch_projects(['/one'], 8, run: run, timeout: 0) }
  end
  assert error.include?('Could not restore VS Code windows: Hyprland focus: Invalid dispatcher'), error
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
    windows = [{ 'class' => 'com.microsoft.VSCode', 'address' => '0x1' }, { 'class' => 'com.microsoft.VSCode', 'address' => '0x2' },
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
    result = run_archon(%w[w vsc stop])
    equal 0, result[:status]
    assert result[:stdout].include?('Closed all VS Code windows.')
    equal windows.drop(2), JSON.parse(File.read(state_path))
    calls = File.readlines(File.join(fixture[:home], 'hyprctl-calls')).map { |line| JSON.parse(line) }
    equal [%w[-j clients], ['dispatch', 'hl.dsp.window.close({ window = "address:0x1" })'], ['dispatch', 'hl.dsp.window.close({ window = "address:0x2" })'], %w[-j clients]], calls
    result = run_archon(%w[w vsc stop])
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
      output = JSON.generate(listings < 3 ? [{ 'class' => 'com.microsoft.VSCode', 'address' => '0x1' }] : [])
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
    output = arguments == %w[-j clients] ? '[{"class":"com.microsoft.VSCode","address":"0x1"}]' : 'ok'
    { stdout: output, stderr: '', status: 0 }
  end
  raises(/did not finish closing/) { VSC.stop_windows(run: stuck, timeout: 0) }
  failed = ->(*_) { { stdout: '', stderr: 'disconnected', status: 1 } }
  status, output, error = capture { VSC.run_visual_studio_code(['stop'], run: failed) }
  equal 1, status
  assert !output.include?('Closed')
  assert error.include?('disconnected')
end
