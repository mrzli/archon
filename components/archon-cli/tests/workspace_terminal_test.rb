require_relative 'workspace_helpers'

test('tmux checklist saves choices, restores defaults, ignores deleted projects, and attaches in the current terminal') do
  fixture do |fixture|
    ENV['TMW_TMUX_STATE'] = File.join(fixture[:root], 'tmux')
    first = workspace_directory(fixture, 'cloned/one')
    second = workspace_directory(fixture, 'personal/owner/two')
    status, text = workspace_terminal(%w[w t start]) do |terminal, wait, text|
      wait.call('Choose projects')
      assert !text.include?('Choose workspace')
      terminal.write(" \r")
    end
    equal 0, status
    path = File.join(ENV['XDG_STATE_HOME'], 'archon/workspaces/tmux.json')
    equal({ 'projects' => [first] }, JSON.parse(File.read(path)))
    name = Archon::Workspaces.project_definitions([first]).first[:session]
    equal "=#{name}\n", File.read(File.join(ENV['TMW_TMUX_STATE'], 'attachments'))
    FileUtils.rm_rf(first)
    status, = workspace_terminal(%w[w t start], environment: { 'TMUX' => 'fixture' }) do |terminal, wait, text|
      wait.call('Choose projects')
      assert text.include?('[ ] personal/owner/two')
      terminal.write(" \r")
    end
    equal 0, status
    equal({ 'projects' => [second] }, JSON.parse(File.read(path)))
    equal "=#{name}\n", File.read(File.join(ENV['TMW_TMUX_STATE'], 'attachments'))
  end
end

test('terminal checklist cancellation preserves state and empty choices save without backend operations') do
  fixture do |fixture|
    workspace_directory(fixture)
    path = File.join(ENV['XDG_STATE_HOME'], 'archon/workspaces/tmux.json')
    Archon::WorkspaceProjects.save_selection(path, { 'projects' => [File.join(fixture[:home], 'deleted')] })
    before = File.read(path)
    [["\e", 0], ["\u0003", 130]].each do |key, expected|
      status, = workspace_terminal(%w[w t start]) do |terminal, wait, _|
        wait.call('Choose projects')
        terminal.write(key)
      end
      equal expected, status
      equal before, File.read(path)
    end
    status, = workspace_terminal(%w[w t start]) do |terminal, wait, _|
      wait.call('Choose projects')
      terminal.write("\r")
    end
    equal 0, status
    equal({ 'projects' => [] }, JSON.parse(File.read(path)))
    assert !File.exist?(File.join(fixture[:root], 'tmux'))
    equal 1, run_archon(%w[w t start])[:status]
    equal 1, run_archon(%w[w h start])[:status]
  end
end

test('Herdr uses the same checklist and actual terminal attachment rules') do
  fixture do |fixture|
    project = workspace_directory(fixture)
    path = File.join(fixture[:root], 'herdr.json')
    File.write(path, JSON.generate(running: false, workspaces: [], calls: [], next_id: 0, attachments: 0))
    ENV['HERDR_TEST_STATE'] = path
    [{}, { 'HERDR_ENV' => '1' }].each do |environment|
      status, = workspace_terminal(%w[w h start --ai claude], environment: environment) do |terminal, wait, text|
        wait.call('Choose projects')
        assert !text.include?('Choose workspace')
        terminal.write(environment.empty? ? " \r" : "\r")
      end
      equal 0, status
    end
    state = JSON.parse(File.read(path))
    equal 1, state['attachments']
    equal 1, state['workspaces'].length
    equal project, state['workspaces'].first['cwd']
    equal %w[nvim claude shell], state['workspaces'].first['tabs'].map { |tab| tab['label'] }
  end
end

test('an isolated installed CLI selects and starts projects through both executable aliases') do
  fixture do |fixture|
    project = workspace_directory(fixture, 'cloned/plain project')
    ENV['TMW_TMUX_STATE'] = File.join(fixture[:root], 'tmux')
    repo = File.expand_path('../../..', __dir__)
    result = Archon::Shared.run_process(RbConfig.ruby, ['-r', File.join(repo, 'setup/setup.rb'), '-e', 'install_archon_cli(*ARGV)', repo, fixture[:home]])
    equal 0, result[:status]
    %w[archon arc].each_with_index do |name, index|
      executable = File.join(fixture[:home], '.local/bin', name)
      status, = workspace_terminal(%w[w t start], executable: executable) do |terminal, wait, text|
        wait.call('Choose projects')
        assert text.include?('[x] cloned/plain project') unless index.zero?
        terminal.write(index.zero? ? " \r" : "\r")
      end
      equal 0, status
    end
    directory = File.join(ENV['TMW_TMUX_STATE'], 'sessions')
    equal 1, Dir.children(directory).length
    equal project, File.read(File.join(directory, Dir.children(directory).first, 'root')).strip
    equal({ 'projects' => [project] }, JSON.parse(File.read(File.join(ENV['XDG_STATE_HOME'], 'archon/workspaces/tmux.json'))))
  end
end
