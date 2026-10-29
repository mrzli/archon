require_relative 'test_helpers'

check('mise installs tools despite system executables and skips repeat installations', :tools) do |repo, _home, bin, env|
  File.symlink("#{bin}/go", "#{bin}/rustc")
  File.write("#{env.fetch('SYSTEM_FIXTURE')}/mise-tools.json", '{}')
  2.times do
    _, error, status = Open3.capture3(env, RbConfig.ruby, '-r', "#{repo}/setup/setup.rb",
                                    '-e', 'install_development_environments; install_mise_tools')
    assert status.success?, error
  end
  installs = commands(env).reject { |args| args[0, 2] == %w[mise ls] }
  assert installs == %w[ruby python node bun go rust zig].map { |tool| %W[omarchy install dev-env #{tool}] } +
                     %w[pnpm codex claude shellcheck].map { |tool| %W[mise use --global #{tool}] }
end

check('mise requires installed versions and rejects system passthrough', :tools) do |repo, _home, _bin, env|
  state = "#{env.fetch('SYSTEM_FIXTURE')}/mise-tools.json"
  tools = JSON.parse(File.read(state))
  tools['pnpm'] = [{ 'version' => 'system', 'installed' => true }]
  tools['go'] = [{ 'version' => '1.0', 'installed' => false }]
  tools['zls'] = []
  File.write(state, JSON.generate(tools))
  _, error, status = Open3.capture3(env, RbConfig.ruby, '-r', "#{repo}/setup/setup.rb",
                                  '-e', 'install_development_environments; install_mise_tools')
  assert status.success?, error
  installs = commands(env).reject { |args| args[0, 2] == %w[mise ls] }
  assert installs == [*%w[go rust zig].map { |tool| %W[omarchy install dev-env #{tool}] },
                      *%w[pnpm codex claude shellcheck].map { |tool| %W[mise use --global #{tool}] }]
end

check('Ruby LSP and Claude Code plugins install once on a fresh Claude Code', :tools) do |repo, _home, _bin, env|
  2.times do
    _, error, status = Open3.capture3(env, RbConfig.ruby, '-r', "#{repo}/setup/setup.rb",
                                    '-e', 'install_ruby_gems; install_claude_plugins')
    assert status.success?, error
  end
  installs = commands(env).reject { |args| args.include?('list') }
  claude = [%w[plugin marketplace add anthropics/claude-plugins-official],
            %w[plugin install clangd-lsp@claude-plugins-official --scope user],
            %w[plugin install ruby-lsp@claude-plugins-official --scope user]]
  assert installs == [%w[mise exec ruby -- gem install ruby-lsp],
                      *claude.flat_map { |arguments| [%w[setsid -w claude] + arguments, ['claude', *arguments]] }]
end

check('web app removal skips absent apps and suppresses removal notifications', :applications) do |repo, home, _bin, env|
  launcher = "#{home}/.local/share/applications/nested/HEY.desktop"
  FileUtils.mkdir_p(File.dirname(launcher))
  File.write(launcher, "[Desktop Entry]\n")
  _, error, status = run_operation(repo, env, 'remove_unwanted_webapps(home)')
  assert status.success?, error
  assert commands(env).select { |args| args[0, 2] == %w[omarchy webapp] } == [%w[omarchy webapp remove HEY]]
  assert File.read("#{env.fetch('SYSTEM_FIXTURE')}/webapp-notify") == 'false'
end

check('Hyprland reload fails on configuration errors and is skipped outside a session', :hyprland) do |repo, _home, _bin, env|
  _, error, status = run_operation(repo, env, 'reload_hyprland')
  assert status.success?, error
  assert commands(env) == [%w[hyprctl reload], %w[hyprctl -j configerrors]]
  _, error, status = run_operation(repo, env.merge('HYPRLAND_ERRORS' => '["line 3: bad keyword"]'), 'reload_hyprland')
  assert status.exitstatus == 1
  assert error.include?('line 3: bad keyword'), error
  calls = commands(env).length
  _, error, status = run_operation(repo, env.merge('HYPRLAND_INSTANCE_SIGNATURE' => nil), 'reload_hyprland')
  assert status.success?, error
  assert commands(env).length == calls
end

check('help and invalid arguments do not provision', :none) do |repo, _home, _bin, env|
  assert run_setup(repo, env, '--help').last.success?
  assert run_setup(repo, env, '--unknown').last.exitstatus == 2
  %w[-d --rootless-docker --delete-managed-home-dirs].each do |option|
    assert run_setup(repo, env, option).last.exitstatus == 2
  end
  assert commands(env).empty?
end

check('bootstrap supports existing Ruby and installation through mise', :tools) do |repo, _home, bin, env|
  launch = -> { Open3.capture3(env, '/bin/bash', "#{repo}/setup.sh", '--help') }
  output, error, status = launch.call
  assert status.success?, error
  assert output.include?('Usage: setup.sh')
  assert commands(env) == [
    %w[omarchy install dev-env ruby],
    ['mise', 'exec', 'ruby', '--', 'ruby', "#{repo}/setup/main.rb", '--help']
  ]
  File.symlink(RbConfig.ruby, "#{bin}/ruby")
  count = commands(env).length
  assert launch.call.last.success?
  assert commands(env).length == count
end

check('repeat runs preserve user files and avoid duplicate configuration', :full) do |repo, home, _bin, env|
  FileUtils.mkdir_p(["#{home}/Projects", "#{home}/.claude"])
  File.write("#{home}/.claude/settings.json", '{"theme": "dark"}')
  2.times do
    output, error, status = run_setup(repo, env)
    assert status.success?, error
    assert output.include?("Installed but not in data/vscode-extensions.txt:\n      unlisted.extension\n")
    assert !File.exist?("#{home}/Projects")
  end
  assert File.read("#{home}/personal-file") == "preserve\n"
  assert File.read("#{home}/managed-file") == "managed\n"
  output, error, status = Open3.capture3(env, RbConfig.ruby, "#{home}/.local/bin/archon", '--help')
  assert status.success?, error
  assert output.include?('Usage: archon')
  assert File.symlink?("#{home}/.local/bin/arc")
  assert JSON.parse(File.read("#{home}/.config/nvim/lazyvim.json"))['extras'] == ['lazyvim.plugins.extras.util.rest']
  claude_settings = JSON.parse(File.read("#{home}/.claude/settings.json"))
  assert claude_settings['theme'] == 'dark'
  assert claude_settings['statusLine'] == { 'type' => 'command', 'command' => 'bash ~/.claude/statusline-command.sh' }
  assert claude_settings['cleanupPeriodDays'] == 365
  assert File.read("#{home}/.bashrc").scan('source ').length == 1
  assert commands(env).none? { |args| args.include?('existing.extension') }
  assert commands(env).count { |args| args.include?('clone') } == 1
  assert commands(env).count { |args| args.include?('pull') } == 1
  %w[.agents .claude].each do |directory|
    path = "#{home}/#{directory}/skills/example"
    assert File.readlink(path) == "#{env.fetch('XDG_DATA_HOME')}/archon/skills/skills/productivity/example"
    assert File.read("#{path}/SKILL.md") == 'example skill'
  end
  %w[voxtype.service.d/10-archon.conf docker.service].each do |service|
    relative = ".config/systemd/user/#{service}"
    assert File.read("#{home}/#{relative}") == File.read("#{repo}/data/home/#{relative}")
  end
  assert File.read("#{home}/.config/systemd/user/voxtype.service.d/10-archon.conf").include?('Environment=VK_DRIVER_FILES=/usr/share/vulkan/icd.d/nvidia_icd.json')
end

check('a populated ~/Projects fails setup and keeps its contents', :none) do |repo, home, _bin, env|
  FileUtils.mkdir_p("#{home}/Projects")
  File.write("#{home}/Projects/.keep", 'user data')
  _, error, status = run_operation(repo, env, 'remove_default_projects_directory(home)')
  assert status.exitstatus == 1
  assert error.include?('~/Projects is not empty')
  assert File.read("#{home}/Projects/.keep") == 'user data'
end

check('failed skills updates preserve installed skills and links', :skills) do |repo, home, _bin, env|
  _, error, status = run_operation(repo, env, 'install_user_skills(home)')
  assert status.success?, error
  source = "#{env.fetch('XDG_DATA_HOME')}/archon/skills/skills/productivity/example"
  _, error, status = run_operation(repo, env.merge('FAIL_COMMAND' => 'git'), 'install_user_skills(home)')
  assert !status.success?, error
  %w[.agents .claude].each do |directory|
    assert File.read("#{home}/#{directory}/skills/example/SKILL.md") == 'example skill'
  end
  FileUtils.rm_r(File.dirname(source))
  _, error, status = run_operation(repo, env, 'install_user_skills(home)')
  assert status.success?, error
  assert Dir.empty?(File.dirname(File.dirname(source)))
  assert !File.exist?("#{env.fetch('XDG_DATA_HOME')}/archon-skills")
  %w[.agents .claude].each do |directory|
    assert !File.symlink?("#{home}/#{directory}/skills/example")
  end
end

check('default setup replaces managed directories', :files) do |repo, home, _bin, env|
  FileUtils.mkdir_p(["#{repo}/data/home/.config/managed", "#{home}/.config/managed"])
  File.write("#{repo}/data/home/.config/managed/current", 'current')
  2.times do |index|
    service = '.config/systemd/user/docker.service'
    File.write("#{repo}/data/home/#{service}", "[Service]\nExecStart=/#{'updated-' * index}launcher\n")
    File.write("#{home}/.config/managed/obsolete", 'obsolete')
    _, error, status = run_operation(repo, env, 'install_home_files(repo, home)')
    assert status.success?, error
    assert Dir.children("#{home}/.config/managed") == ['current']
    assert File.read("#{home}/#{service}") == File.read("#{repo}/data/home/#{service}")
    assert File.read("#{home}/personal-file") == "preserve\n"
  end
end

check('Battle.net installs once and skips the installed launcher on reruns', :applications) do |repo, _home, _bin, env|
  2.times do
    _, error, status = run_operation(repo, env, 'install_applications')
    assert status.success?, error
  end
  assert commands(env).count { |args| args == %w[omarchy install gaming battlenet] } == 1
end

check('voice AI installs without desktop notifications and preserves existing config', :voice) do |repo, home, _bin, env|
  _, error, status = run_operation(repo, env, 'install_voice_ai')
  assert status.success?, error
  config = "#{home}/.config/voxtype/config.toml"
  assert File.read(config) == "[hotkey]\nenabled = false\n"
  File.write(config, "# personal configuration\n")

  _, error, status = run_operation(repo, env, 'install_voice_ai')
  assert status.success?, error
  assert File.read(config) == "# personal configuration\n"
  assert commands(env).none? { |args| args == %w[omarchy voxtype install] }
  assert commands(env).count { |args| args == %w[omarchy pkg add wtype voxtype-bin] } == 2
end

check('GPU dictation requests the model and skips unchanged settings and variant on reruns', :voice) do |repo, _home, _bin, env|
  _, error, status = run_operation(repo, env, 'configure_voice_ai')
  assert status.success?, error
  first_run_count = commands(env).length
  _, error, status = run_operation(repo, env, 'configure_voice_ai')
  assert status.success?, error
  later_calls = commands(env).drop(first_run_count)
  assert later_calls.none? { |args| args[0, 2] == %w[sudo voxtype] || args[0, 3] == %w[voxtype config set] }
  calls = commands(env)
  download = %w[voxtype setup --download --model large-v3-turbo --no-post-install]
  switch = %w[sudo voxtype setup variant --to voxtype-vulkan]
  assert calls.select { |args| args[0, 2] == %w[voxtype setup] } == [download, download]
  assert calls.select { |args| args[0, 2] == %w[sudo voxtype] } == [switch]
  settings = calls.select { |args| args[0, 3] == %w[voxtype config set] }
  assert settings.sort == [
    %w[voxtype config set audio.max_duration_secs 300],
    %w[voxtype config set whisper.model large-v3-turbo],
    %w[voxtype config set whisper.gpu_isolation false],
    %w[voxtype config set whisper.on_demand_loading false],
    %w[voxtype config set whisper.gpu_device 0]
  ].sort
  assert calls.index(download) < calls.index(switch)
  assert calls.index(switch) < calls.index(settings.first)
  assert calls.index(settings.last) < calls.index(%w[systemctl --user restart voxtype.service])
  assert later_calls.include?(%w[systemctl --user restart voxtype.service])
end

check('failed voice downloads preserve configuration and do not switch or restart Voxtype', :voice) do |repo, _home, _bin, env|
  assert run_operation(repo, env.merge('FAIL_VOICE_DOWNLOAD' => '1'), 'configure_voice_ai').last.exitstatus == 1
  assert commands(env).none? { |args|
    args[0, 2] == %w[sudo voxtype] || args[0, 3] == %w[voxtype config set] || args.include?('voxtype.service')
  }
end

check('missing Vulkan variant stops before downloading a model', :voice) do |repo, _home, _bin, env|
  _, error, status = run_operation(repo, env.merge('NO_VULKAN' => '1'), 'configure_voice_ai')
  assert status.exitstatus == 1
  assert error.include?('Vulkan variant is missing')
  assert commands(env).none? { |args| args[0, 3] == %w[voxtype setup --download] }
end

check('failed commands stop setup', :full) do |repo, _home, _bin, env|
  output, _, status = run_setup(repo, env.merge('FAIL_COMMAND' => 'omarchy'))
  assert status.exitstatus == 1
  assert commands(env).length == 1 && commands(env).first.first == 'omarchy'
  assert !output.include?('Setup complete.')
end

check('setup provisions Codex model, subagent, navigation, and status-line settings', :codex) do |repo, _home, _bin, env|
  2.times do
    _, error, status = run_operation(repo, env, 'configure_codex')
    assert status.success?, error
    assert !error.include?('codex startup log'), 'Codex log was shown after success'
  end
  edits = JSON.parse(File.read("#{env.fetch('SYSTEM_FIXTURE')}/codex-edits.json"))
  keys = edits.map { |edit| edit.fetch('keyPath') }
  assert !edits.empty? && keys.uniq == keys
  assert edits.all? { |edit| edit['mergeStrategy'] == 'replace' && edit.key?('value') }
  # Alt+Up/Down stay free for Herdr workspace navigation.
  assert (keys & %w[tui.keymap.chat.edit_queued_message tui.keymap.chat.prompt_stack_back]).length == 2
end

check('Codex configuration failures stop setup', :codex) do |repo, _home, _bin, env|
  assert run_operation(repo, env.merge('FAIL_COMMAND' => 'codex'), 'configure_codex').last.exitstatus == 1
  _, error, status = run_operation(repo, env.merge('CODEX_CRASH' => '1'), 'configure_codex')
  assert status.exitstatus == 1
  assert error.include?('codex startup log') && error.include?('exited before replying'), error
end

check('CLI installation copies Ruby directly without Bun or build tooling', :cli) do |repo, home, bin, env|
  assert !File.exist?("#{bin}/bun")
  _, error, status = run_operation(repo, env, 'install_archon_cli(repo, home)')
  assert status.success?, error
  assert commands(env).none? { |args| args.include?('bun') }
  assert File.exist?("#{home}/.local/lib/archon/cli.rb")
  assert !File.exist?("#{home}/.local/lib/archon/commands/projects/libs/README.md")
end

check('managed deletion rejects entries that resolve to home or outside it', :files) do |repo, home, _bin, env|
  File.write("#{repo}/outside-keep", 'safe')
  ['.', '..', '../outside', '.config/../..', './'].each do |entry|
    File.write("#{repo}/data/home-replace-directories.txt", "#{entry}\n")
    _, error, status = run_operation(repo, env, 'install_home_files(repo, home)')
    assert status.exitstatus == 1, "#{entry} was accepted"
    assert error.include?('Invalid managed home directory'), error
    assert File.read("#{home}/personal-file") == "preserve\n"
  end
  assert File.read("#{repo}/outside-keep") == 'safe'
end

check('managed deletion confines absolute entries to home and removes files and dangling links', :files) do |repo, home, _bin, env|
  FileUtils.mkdir_p(["#{home}/.config/managed", "#{home}/.config/hypr"])
  File.write("#{home}/.config/managed/obsolete", 'obsolete')
  File.write("#{home}/.config/managed-file", 'obsolete')
  File.symlink("#{home}/missing-target", "#{home}/.config/dangling")
  File.write("#{repo}/data/home-replace-directories.txt", "/.config/managed\n.config/managed-file\n.config/dangling\n")
  2.times do
    _, error, status = run_operation(repo, env, 'install_home_files(repo, home)')
    assert status.success?, error
  end
  assert !File.exist?("#{home}/.config/managed") && !File.exist?("#{home}/.config/managed-file")
  assert !File.symlink?("#{home}/.config/dangling")
  assert File.read("#{home}/.config/hypr/hyprland.lua") == "-- existing user configuration\n"
end

check('managed deletion rejects symlinks outside home', :files) do |repo, home, _bin, env|
  outside = "#{repo}/outside"
  FileUtils.mkdir_p([outside, "#{home}/.config"])
  File.write("#{outside}/keep", 'safe')
  File.symlink(outside, "#{home}/.config/managed")
  _, error, status = run_operation(repo, env, 'install_home_files(repo, home)')
  assert status.exitstatus == 1
  assert error.include?('Invalid managed home directory')
  assert File.read("#{outside}/keep") == 'safe'
end

check('rootless setup needs no sudo or dependency installation on a second run', :docker) do |repo, home, _bin, env|
  first_output, error, status = run_operation(repo, env, 'configure_rootless_docker(home)')
  assert status.success?, error
  first_run_count = commands(env).length
  second_output, error, status = run_operation(repo, env, 'configure_rootless_docker(home)')
  assert status.success?, error
  second_run = commands(env).drop(first_run_count)
  assert second_run.none? { |args| args.first == 'sudo' }
  assert first_output.include?('Existing rootful Docker data is preserved')
  assert !second_output.include?('rootful') && !second_output.include?('Log out'), second_output
  assert second_run.none? { |args| args[0, 3] == %w[omarchy pkg add] && (args & %w[rootlesskit slirp4netns]).any? }
  assert second_run.any? { |args| args.first == 'docker' && args.include?('info') }
  assert commands(env).take(first_run_count).include?(%w[systemctl --user start docker.service])
  assert second_run.none? { |args| args[0, 2] == ['systemctl', '--user'] && %w[start restart].include?(args[2]) }
  %w[subuid subgid].each do |file|
    assert File.read("#{env['SYSTEM_FIXTURE']}/#{file}") == "other:100000:65536\ndeveloper:165536:65536\n"
  end
  calls = commands(env)
  assert calls.count { |args| args.first == 'curl' } == 1
  assert calls.index { |args| args.first == 'docker' && args.include?('info') } < calls.index(%w[sudo systemctl disable --now docker.service docker.socket])
  assert calls.none? { |args| args.include?('aur') || args.include?('sudoless-docker') }
  assert File.executable?("#{home}/.local/lib/archon-docker/dockerd-rootless.sh")
end

check('rootless setup handles missing subid files and enabled but inactive rootful Docker', :docker) do |repo, _home, _bin, env|
  state = env.fetch('SYSTEM_FIXTURE')
  %w[subuid subgid].each { |file| File.unlink("#{state}/#{file}") }
  File.write("#{state}/is-active", 'no')
  _, error, status = run_operation(repo, env, 'configure_rootless_docker(home)')
  assert status.success?, error
  %w[subuid subgid].each do |file|
    assert File.read("#{state}/#{file}") == "developer:100000:65536\n"
    assert commands(env).include?(['sudo', 'touch', "/etc/#{file}"])
  end
  assert commands(env).include?(%w[sudo systemctl disable --now docker.service docker.socket])
end

check('rootless setup repairs changed state on later runs', :docker) do |repo, home, _bin, env|
  _, error, status = run_operation(repo, env, 'configure_rootless_docker(home)')
  assert status.success?, error
  first_run_count = commands(env).length
  state = env.fetch('SYSTEM_FIXTURE')
  File.unlink("#{state}/slirp4netns")
  File.write("#{state}/subuid", "other:100000:65536\ndeveloper:165536:1000\n")
  File.write("#{state}/linger", 'no')
  File.write("#{state}/is-active", 'yes')
  File.write("#{state}/groups", 'developer wheel docker')
  _, error, status = run_operation(repo, env, 'configure_rootless_docker(home)')
  assert status.success?, error
  later_calls = commands(env).drop(first_run_count)
  assert later_calls.include?(%w[omarchy pkg add slirp4netns])
  assert later_calls.select { |args| args.first == 'sudo' } == [
    %w[sudo usermod --add-subuids 166536-232071 developer],
    %w[sudo loginctl enable-linger developer],
    %w[sudo systemctl disable --now docker.service docker.socket],
    %w[sudo gpasswd -d developer docker]
  ]
end

check('rootless Docker restarts only when its launcher, subordinate IDs or unit file changed', :docker) do |repo, home, _bin, env|
  restarts = -> { commands(env).count { |args| args == %w[systemctl --user restart docker.service] } }
  _, error, status = run_operation(repo, env.merge('DOCKER_START_TIME' => '1000'), 'configure_rootless_docker(home)')
  assert status.success?, error
  expect_restarts = ->(expected) { assert restarts.call == expected, "expected #{expected} restarts, got #{restarts.call}" }
  expect_restarts.call(0)
  _, error, status = run_operation(repo, env.merge('DOCKER_VERSION' => '30.0.0', 'DOCKER_START_TIME' => '2000'),
                                   'configure_rootless_docker(home)')
  assert status.success?, error
  expect_restarts.call(1)
  File.write("#{env.fetch('SYSTEM_FIXTURE')}/subuid", "other:100000:65536\ndeveloper:165536:1000\n")
  _, error, status = run_operation(repo, env.merge('DOCKER_VERSION' => '30.0.0', 'DOCKER_START_TIME' => '3000'),
                                   'configure_rootless_docker(home)')
  assert status.success?, error
  expect_restarts.call(2)
  unit = "#{home}/.config/systemd/user/docker.service"
  FileUtils.mkdir_p(File.dirname(unit))
  File.write(unit, "[Service]\n")
  File.utime(2500, 2500, unit)
  _, error, status = run_operation(repo, env.merge('DOCKER_VERSION' => '30.0.0'), 'configure_rootless_docker(home)')
  assert status.success?, error
  expect_restarts.call(2)
  File.utime(4000, 4000, unit)
  _, error, status = run_operation(repo, env.merge('DOCKER_VERSION' => '30.0.0'), 'configure_rootless_docker(home)')
  assert status.success?, error
  expect_restarts.call(3)
end

check('launcher follows Docker upgrades without script edits', :docker) do |repo, home, _bin, env|
  _, error, status = run_operation(repo, env, 'configure_rootless_docker(home)')
  assert status.success?, error
  _, error, status = run_operation(repo, env.merge('DOCKER_VERSION' => '30.0.0'), 'configure_rootless_docker(home)')
  assert status.success?, error
  downloads = commands(env).select { |args| args.first == 'curl' }
  assert downloads.length == 2
  assert downloads.last.any? { |arg| arg.include?('/docker-v30.0.0/') }
  assert File.read("#{home}/.local/lib/archon-docker/version").strip == '30.0.0'
end

check('corrupted launcher download fails before changing services', :docker) do |repo, home, _bin, env|
  _, error, status = run_operation(repo, env.merge('BAD_DOWNLOAD' => '1'), 'configure_rootless_docker(home)')
  assert status.exitstatus == 1
  assert error.include?('failed')
  assert !File.exist?("#{home}/.local/lib/archon-docker/dockerd-rootless.sh")
  assert commands(env).none? { |args| args.first == 'systemctl' && args.include?('docker.service') }
end

check('a rootful response fails before disabling the old daemon', :docker) do |repo, _home, _bin, env|
  _, error, status = run_operation(repo, env.merge('ROOTFUL_DOCKER' => '1'), 'configure_rootless_docker(home)')
  assert status.exitstatus == 1
  assert error.include?('did not start in rootless mode')
  assert !commands(env).include?(%w[sudo systemctl disable --now docker.service docker.socket])
end

check('Bash and the desktop session use the same rootless socket', :none) do |_repo, _home, _bin, _env|
  config = File.expand_path('../../data/home/.config', __dir__)
  %w[archon/bashrc uwsm/env.d/20-archon-docker.sh].each do |file|
    output, error, status = Open3.capture3(
      { 'XDG_CONFIG_HOME' => config, 'XDG_RUNTIME_DIR' => '/run/user/1000', 'DOCKER_HOST' => 'unix:///var/run/docker.sock' },
      '/bin/bash', '--noprofile', '--norc', '-c', '. "$1"; printf "%s" "$DOCKER_HOST"', 'bash', "#{config}/#{file}"
    )
    assert status.success?, error
    assert output == 'unix:///run/user/1000/docker.sock'
  end
end

report_checks
