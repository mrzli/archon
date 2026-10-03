require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Standard-library-only checks. All system-changing commands are replaced with stubs.
def assert(condition, message = 'assertion failed')
  raise message unless condition
end

def fixture
  Dir.mktmpdir('archon-setup-') do |root|
    repo = "#{root}/repo with spaces"
    home = "#{root}/home"
    bin = "#{root}/bin"
    FileUtils.mkdir_p(["#{repo}/setup", "#{repo}/data/home", home, bin])
    mise_tools = %w[ruby python node bun zig zls pnpm go].to_h do |tool|
      [tool, [{ 'version' => '1.0', 'installed' => true }]]
    end
    File.write("#{root}/mise-tools.json", JSON.generate(mise_tools))
    %w[setup.sh setup/main.rb setup/setup.rb setup/helpers.rb setup/docker.rb setup/codex.rb setup/workarounds.rb].each do |file|
      FileUtils.cp(File.expand_path("../../#{file}", __dir__), "#{repo}/#{file}")
    end
    cli_source = File.expand_path('../../components/archon-cli', __dir__)
    FileUtils.mkdir_p("#{repo}/components/archon-cli")
    %w[bin lib].each { |directory| FileUtils.cp_r("#{cli_source}/#{directory}", "#{repo}/components/archon-cli/") }
    %w[subuid subgid].each { |file| File.write("#{root}/#{file}", "other:100000:65536\n") }
    { 'linger' => 'no', 'is-enabled' => 'yes', 'is-active' => 'yes', 'groups' => 'developer wheel docker' }.each do |property, value|
      File.write("#{root}/#{property}", value)
    end
    File.write("#{root}/voice-variant", 'whisper-avx2')
    FileUtils.mkdir_p("#{root}/omarchy/default/voxtype")
    File.write("#{root}/omarchy/default/voxtype/config.toml", "[hotkey]\nenabled = false\n")
    File.write("#{root}/voice-config.json", JSON.generate({
      'engine' => 'whisper', 'whisper.model' => 'base.en', 'whisper.mode' => 'local',
      'whisper.language' => 'en', 'audio.device' => 'my microphone', 'hotkey.enabled' => false,
      'whisper.gpu_isolation' => true, 'whisper.on_demand_loading' => true, 'whisper.gpu_device' => 1
    }))
    FileUtils.mkdir_p("#{repo}/data/home/.config/systemd/user/voxtype.service.d")
    FileUtils.cp(File.expand_path('../../data/home/.config/systemd/user/voxtype.service.d/10-archon.conf', __dir__),
                 "#{repo}/data/home/.config/systemd/user/voxtype.service.d/10-archon.conf")
    File.write("#{repo}/data/vscode-extensions.txt", "# extensions\nexisting.extension\nnew.extension\n")
    FileUtils.cp(File.expand_path('../../data/home-copy-ignore.txt', __dir__), "#{repo}/data/home-copy-ignore.txt")
    FileUtils.mkdir_p("#{repo}/data/home/.config/systemd/user")
    FileUtils.cp(File.expand_path('../../data/home/.config/systemd/user/docker.service', __dir__),
                 "#{repo}/data/home/.config/systemd/user/docker.service")
    File.write("#{repo}/data/home-replace-directories.txt", ".config/managed\n")
    File.write("#{repo}/data/home/managed-file", "managed\n")
    File.write("#{home}/personal-file", "preserve\n")
    FileUtils.mkdir_p("#{home}/.config/hypr")
    File.write("#{home}/.config/hypr/hyprland.lua", "-- existing user configuration\n")
    stub = <<~SCRIPT
      #!#{RbConfig.ruby}
      require 'fileutils'
      require 'json'
      name = File.basename($0)
      File.open(ENV.fetch('COMMAND_LOG'), 'a') { |file| file.puts(JSON.generate([name, *ARGV])) }
      exit 1 if ENV['FAIL_COMMAND'] == name
      state = ENV.fetch('SYSTEM_FIXTURE')
      case name
      when 'codex'
        config_path = "\#{state}/codex-config.json"
        config = File.exist?(config_path) ? JSON.parse(File.read(config_path)) : {}
        STDIN.each_line do |line|
          request = JSON.parse(line)
          next unless request.key?('id')

          if request['method'] == 'config/batchWrite'
            edits = request.fetch('params').fetch('edits')
            File.write("\#{state}/codex-edits.json", JSON.generate(edits))
            config['tui'] ||= {}
            config['tui']['status_line'] = edits.find { |edit| edit['keyPath'] == 'tui.status_line' }.fetch('value')
            File.write(config_path, JSON.generate(config))
          end
          puts JSON.generate({ id: request['id'], result: {} })
          STDOUT.flush
        end
      when 'id'
        puts(ARGV.first == '-un' ? 'developer' : ARGV.first == '-u' ? '1000' : File.read("\#{state}/groups"))
      when 'cat'
        puts File.read(File.join(ENV.fetch('SYSTEM_FIXTURE'), File.basename(ARGV.first)))
      when 'test'
        exit(File.exist?(File.join(state, File.basename(ARGV.last))) ? 0 : 1)
      when 'pacman'
        if %w[rootlesskit slirp4netns].include?(ARGV.last)
          exit(File.exist?("\#{state}/\#{ARGV.last}") ? 0 : 1)
        end
      when 'omarchy'
        if ARGV[0, 2] == %w[install dev-env]
          tools = JSON.parse(File.read("\#{state}/mise-tools.json"))
          names = ARGV.last == 'zig' ? %w[zig zls] : [ARGV.last]
          names.each { |tool| tools[tool] = [{ 'version' => '1.0', 'installed' => true }] }
          File.write("\#{state}/mise-tools.json", JSON.generate(tools))
        end
        if ARGV == %w[install gaming battlenet]
          launcher = File.join(ENV.fetch('HOME'), 'Games/battlenet/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe')
          FileUtils.mkdir_p(File.dirname(launcher))
          FileUtils.touch(launcher)
        end
        if ARGV == %w[voxtype install]
          warn 'Call failed: The name is not activatable'
          exit 1
        end
        if ARGV[0, 2] == %w[pkg add]
          if ARGV.include?('voxtype-bin') && !File.exist?(File.join(File.dirname($0), 'voxtype'))
            File.symlink($0, File.join(File.dirname($0), 'voxtype'))
          end
          (ARGV & %w[rootlesskit slirp4netns]).each { |package| FileUtils.touch("\#{state}/\#{package}") }
        end
      when 'voxtype'
        case ARGV[0, 2]
        when %w[info variants]
          puts JSON.generate({ 'active_variant' => File.read("\#{state}/voice-variant"),
                               'variants' => [{ 'binary_name' => 'voxtype-vulkan', 'installed' => !ENV['NO_VULKAN'] }] })
        when %w[setup --download]
          exit 1 if ENV['FAIL_VOICE_DOWNLOAD']
          unless File.exist?("\#{state}/voice-model")
            File.write("\#{state}/voice-model", 'large-v3-turbo')
            File.open("\#{state}/voice-downloads", 'a') { |file| file.puts('download') }
          end
        when %w[config get]
          puts File.read("\#{state}/voice-config.json")
        when %w[config set]
          config = JSON.parse(File.read("\#{state}/voice-config.json"))
          config[ARGV[2]] = begin
            JSON.parse(ARGV[3])
          rescue JSON::ParserError
            ARGV[3]
          end
          File.write("\#{state}/voice-config.json", JSON.generate(config))
        end
      when 'loginctl'
        puts File.read("\#{state}/linger")
      when 'systemctl'
        if %w[is-enabled is-active].include?(ARGV.first)
          exit(File.read("\#{state}/\#{ARGV.first}").strip == 'yes' ? 0 : 1)
        end
      when 'sudo'
        if ARGV[0, 3] == %w[voxtype setup variant]
          File.write("\#{state}/voice-variant", 'whisper-vulkan')
        elsif ARGV.first == 'touch'
          FileUtils.touch(File.join(state, File.basename(ARGV.last)))
        elsif ARGV.first == 'loginctl'
          File.write("\#{state}/linger", 'yes')
        elsif ARGV.first == 'systemctl'
          %w[is-enabled is-active].each { |property| File.write("\#{state}/\#{property}", 'no') }
        elsif ARGV.first == 'gpasswd'
          File.write("\#{state}/groups", 'developer wheel')
        elsif ARGV.first == 'usermod'
          kind = ARGV[1].delete_prefix('--add-sub').delete_suffix('s')
          first = ARGV[2].split('-').first
          File.open("\#{ENV.fetch('SYSTEM_FIXTURE')}/sub\#{kind}", 'a') do |file|
            file.puts "\#{ARGV[3]}:\#{first}:65536"
          end
        end
      when 'curl'
        File.write(ARGV.last, ENV['BAD_DOWNLOAD'] ? '(' : "#!/bin/sh\\nexit 0\\n")
      when 'docker'
        if ARGV == ['--version']
          puts "Docker version \#{ENV.fetch('DOCKER_VERSION', '29.7.2')}, build fixture"
          exit 0
        end
        puts JSON.generate(ENV['ROOTFUL_DOCKER'] ? ['name=seccomp'] : ['name=seccomp', 'name=rootless'])
      when 'code'
        puts 'EXISTING.extension' if ARGV.first == '--list-extensions'
      when 'git'
        if ARGV.include?('clone')
          FileUtils.mkdir_p(["\#{ARGV.last}/.git", "\#{ARGV.last}/skills/productivity/example"])
          File.write("\#{ARGV.last}/skills/productivity/example/SKILL.md", 'example skill')
        end
      when 'rsync'
        exec '/usr/bin/rsync', *ARGV
      when 'mise'
        tools = JSON.parse(File.read("\#{state}/mise-tools.json"))
        if ARGV[0, 4] == %w[ls --global --installed --json]
          puts JSON.generate(tools.fetch(ARGV.last, []).select { |version| version['installed'] })
        elsif ARGV[0, 2] == %w[use --global]
          tools[ARGV.last] = [{ 'version' => '1.0', 'installed' => true }]
          File.write("\#{state}/mise-tools.json", JSON.generate(tools))
        end
        if ARGV[0, 3] == %w[exec ruby --]
          exec #{RbConfig.ruby.inspect}, *ARGV.drop(4)
        end
      end
    SCRIPT
    %w[omarchy pacman code codex git rsync hyprctl mise rails uv node bun zls pnpm go id cat sudo curl docker systemctl loginctl test].each do |command|
      File.write("#{bin}/#{command}", stub)
      File.chmod(0o755, "#{bin}/#{command}")
    end
    %w[realpath dirname].each { |command| File.symlink("/usr/bin/#{command}", "#{bin}/#{command}") }
    env = { 'HOME' => home, 'XDG_DATA_HOME' => "#{home}/.local/share", 'PATH' => bin,
            'COMMAND_LOG' => "#{root}/commands.jsonl", 'SYSTEM_FIXTURE' => root,
            'OMARCHY_PATH' => "#{root}/omarchy" }
    yield repo, home, bin, env
  end
end

def run_setup(repo, env, *arguments)
  Open3.capture3(env, RbConfig.ruby, "#{repo}/setup/main.rb", *arguments)
end

def commands(env)
  File.exist?(env['COMMAND_LOG']) ? File.readlines(env['COMMAND_LOG']).map { |line| JSON.parse(line) } : []
end

checks = {
  'mise installs tools despite system executables and skips repeat installations' => lambda do |repo, _home, bin, env|
    File.symlink("#{bin}/go", "#{bin}/rustc")
    File.write("#{env.fetch('SYSTEM_FIXTURE')}/mise-tools.json", '{}')
    2.times do
      _, error, status = Open3.capture3(env, RbConfig.ruby, '-r', "#{repo}/setup/setup.rb",
                                      '-e', 'install_development_environments; install_mise_tools')
      assert status.success?, error
    end
    installs = commands(env).reject { |args| args[0, 2] == %w[mise ls] }
    assert installs == %w[ruby python node bun zig].map { |tool| %W[omarchy install dev-env #{tool}] } +
                       %w[pnpm go rust codex claude].map { |tool| %W[mise use --global #{tool}] }
  end,
  'mise requires installed versions and rejects system passthrough' => lambda do |repo, _home, _bin, env|
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
    assert installs == [%w[omarchy install dev-env zig], *%w[pnpm go rust codex claude].map { |tool| %W[mise use --global #{tool}] }]
  end,
  'help and invalid arguments do not provision' => lambda do |repo, _home, _bin, env|
    assert run_setup(repo, env, '--help').last.success?
    assert run_setup(repo, env, '--unknown').last.exitstatus == 2
    %w[-d --rootless-docker --delete-managed-home-dirs].each do |option|
      assert run_setup(repo, env, option).last.exitstatus == 2
    end
    assert commands(env).empty?
  end,
  'bootstrap supports existing Ruby and installation through mise' => lambda do |repo, _home, bin, env|
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
  end,
  'repeat runs preserve user files and avoid duplicate configuration' => lambda do |repo, home, _bin, env|
    FileUtils.mkdir_p("#{home}/Projects")
    2.times do
      _, error, status = run_setup(repo, env)
      assert status.success?, error
      assert !File.exist?("#{home}/Projects")
    end
    assert File.read("#{home}/personal-file") == "preserve\n"
    assert File.read("#{home}/managed-file") == "managed\n"
    output, error, status = Open3.capture3(env, RbConfig.ruby, "#{home}/.local/bin/archon", '--help')
    assert status.success?, error
    assert output.include?('Usage: archon')
    assert File.symlink?("#{home}/.local/bin/arc")
    assert JSON.parse(File.read("#{home}/.config/nvim/lazyvim.json"))['extras'] == ['lazyvim.plugins.extras.util.rest']
    assert File.read("#{home}/.bashrc").scan('source ').length == 1
    assert commands(env).none? { |args| args.include?('existing.extension') }
    assert commands(env).count { |args| args.include?('clone') } == 1
    assert commands(env).count { |args| args.include?('pull') } == 1
    %w[.agents .claude].each do |directory|
      path = "#{home}/#{directory}/skills/example"
      assert File.readlink(path) == "#{env.fetch('XDG_DATA_HOME')}/archon-skills/skills/productivity/example"
      assert File.read("#{path}/SKILL.md") == 'example skill'
    end
  end,
  'populated Projects stops setup and preserves its contents' => lambda do |repo, home, _bin, env|
    FileUtils.mkdir_p("#{home}/Projects")
    File.write("#{home}/Projects/.keep", 'user data')
    output, error, status = run_setup(repo, env)
    assert status.exitstatus == 1
    assert error.include?('~/Projects is not empty')
    assert !output.include?('Setup complete.')
    assert File.read("#{home}/Projects/.keep") == 'user data'
  end,
  'failed skills updates preserve installed skills and links' => lambda do |repo, home, _bin, env|
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    source = "#{env.fetch('XDG_DATA_HOME')}/archon-skills/skills/productivity/example"
    _, error, status = run_setup(repo, env.merge('FAIL_COMMAND' => 'git'))
    assert !status.success?, error
    %w[.agents .claude].each do |directory|
      assert File.read("#{home}/#{directory}/skills/example/SKILL.md") == 'example skill'
    end
    FileUtils.rm_r(File.dirname(source))
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    assert Dir.empty?(File.dirname(File.dirname(source)))
    assert !File.exist?("#{env.fetch('XDG_DATA_HOME')}/archon/skills")
    %w[.agents .claude].each do |directory|
      assert !File.symlink?("#{home}/#{directory}/skills/example")
    end
  end,
  'default setup replaces managed directories' => lambda do |repo, home, _bin, env|
    FileUtils.mkdir_p(["#{repo}/data/home/.config/managed", "#{home}/.config/managed"])
    File.write("#{repo}/data/home/.config/managed/current", 'current')
    2.times do
      File.write("#{home}/.config/managed/obsolete", 'obsolete')
      _, error, status = run_setup(repo, env)
      assert status.success?, error
      assert Dir.children("#{home}/.config/managed") == ['current']
      assert File.read("#{home}/personal-file") == "preserve\n"
    end
  end,
  'Battle.net installs once and skips the installed launcher on reruns' => lambda do |repo, _home, _bin, env|
    2.times do
      _, error, status = run_setup(repo, env)
      assert status.success?, error
    end
    assert commands(env).count { |args| args == %w[omarchy install gaming battlenet] } == 1
  end,
  'voice AI installs without desktop notifications and preserves existing config' => lambda do |repo, home, _bin, env|
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    config = "#{home}/.config/voxtype/config.toml"
    assert File.read(config) == "[hotkey]\nenabled = false\n"
    File.write(config, "# personal configuration\n")

    _, error, status = run_setup(repo, env)
    assert status.success?, error
    assert File.read(config) == "# personal configuration\n"
    assert commands(env).none? { |args| args == %w[omarchy voxtype install] }
    assert commands(env).count { |args| args == %w[omarchy pkg add wtype voxtype-bin] } == 2
  end,
  'GPU dictation converges without repeated downloads, settings writes, or sudo' => lambda do |repo, home, _bin, env|
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    first_run_count = commands(env).length
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    later_calls = commands(env).drop(first_run_count)
    assert later_calls.none? { |args| args[0, 2] == %w[sudo voxtype] || args[0, 3] == %w[voxtype config set] }
    state = env.fetch('SYSTEM_FIXTURE')
    assert File.read("#{state}/voice-variant") == 'whisper-vulkan'
    assert File.readlines("#{state}/voice-downloads").length == 1
    config = JSON.parse(File.read("#{state}/voice-config.json"))
    assert config['audio.max_duration_secs'] == 300
    assert config.values_at('engine', 'whisper.mode', 'whisper.model') == %w[whisper local large-v3-turbo]
    assert config.values_at('whisper.gpu_isolation', 'whisper.on_demand_loading', 'whisper.gpu_device') == [false, false, 0]
    assert config.values_at('whisper.language', 'audio.device', 'hotkey.enabled') == ['en', 'my microphone', false]
    override = "#{home}/.config/systemd/user/voxtype.service.d/10-archon.conf"
    assert File.read(override).include?('Environment=VK_DRIVER_FILES=/usr/share/vulkan/icd.d/nvidia_icd.json')
    assert later_calls.include?(%w[systemctl --user restart voxtype.service])
  end,
  'failed voice downloads preserve configuration and do not switch or restart Voxtype' => lambda do |repo, _home, _bin, env|
    config_path = "#{env.fetch('SYSTEM_FIXTURE')}/voice-config.json"
    original = File.read(config_path)
    assert run_setup(repo, env.merge('FAIL_VOICE_DOWNLOAD' => '1')).last.exitstatus == 1
    assert File.read(config_path) == original
    assert commands(env).none? { |args| args[0, 2] == %w[sudo voxtype] || args.include?('voxtype.service') }
  end,
  'missing Vulkan variant stops before downloading a model' => lambda do |repo, _home, _bin, env|
    _, error, status = run_setup(repo, env.merge('NO_VULKAN' => '1'))
    assert status.exitstatus == 1
    assert error.include?('Vulkan variant is missing')
    assert commands(env).none? { |args| args[0, 3] == %w[voxtype setup --download] }
  end,
  'failed commands stop setup' => lambda do |repo, _home, _bin, env|
    assert run_setup(repo, env.merge('FAIL_COMMAND' => 'omarchy')).last.exitstatus == 1
    assert commands(env) == [%w[omarchy pkg drop aether obsidian]]
  end,
  'setup provisions Codex model, subagent, navigation, and status-line settings' => lambda do |repo, _home, _bin, env|
    2.times do
      _, error, status = run_setup(repo, env)
      assert status.success?, error
    end
    edits = JSON.parse(File.read("#{env.fetch('SYSTEM_FIXTURE')}/codex-edits.json"))
    assert edits == [
      { 'keyPath' => 'model', 'value' => 'gpt-6.1-sol', 'mergeStrategy' => 'replace' },
      { 'keyPath' => 'model_reasoning_effort', 'value' => 'high', 'mergeStrategy' => 'replace' },
      { 'keyPath' => 'agents.enabled', 'value' => true, 'mergeStrategy' => 'replace' },
      { 'keyPath' => 'agents.default_subagent_model', 'value' => 'gpt-6-luna', 'mergeStrategy' => 'replace' },
      { 'keyPath' => 'agents.default_subagent_reasoning_effort', 'value' => 'high', 'mergeStrategy' => 'replace' },
      { 'keyPath' => 'tui.status_line', 'value' => %w[model-with-reasoning current-dir git-branch thread-name context-used weekly-limit], 'mergeStrategy' => 'replace' },
      { 'keyPath' => 'tui.keymap.chat.edit_queued_message', 'value' => 'alt-shift-up', 'mergeStrategy' => 'replace' },
      { 'keyPath' => 'tui.keymap.chat.prompt_stack_back', 'value' => 'alt-shift-down', 'mergeStrategy' => 'replace' }
    ]
  end,
  'Codex footer converges on the requested fields and ordering' => lambda do |repo, _home, _bin, env|
    config_path = "#{env.fetch('SYSTEM_FIXTURE')}/codex-config.json"
    expected = %w[model-with-reasoning current-dir git-branch thread-name context-used weekly-limit]
    [nil, [], %w[git-branch weekly-limit model context-used], %w[context-used weekly-limit]].each do |existing|
      config = { 'tui' => { 'status_line' => existing, 'show_tooltips' => false } }
      File.write(config_path, JSON.generate(config))
      2.times do
        _, error, status = Open3.capture3(env, RbConfig.ruby, '-r', "#{repo}/setup/codex.rb", '-e', 'configure_codex')
        assert status.success?, error
        updated = JSON.parse(File.read(config_path))
        assert updated.dig('tui', 'status_line') == expected
        assert updated.dig('tui', 'show_tooltips') == false
      end
    end
  end,
  'Codex configuration failures stop setup' => lambda do |repo, _home, _bin, env|
    assert run_setup(repo, env.merge('FAIL_COMMAND' => 'codex')).last.exitstatus == 1
  end,
  'CLI installation copies Ruby directly without build tooling' => lambda do |repo, home, _bin, env|
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    assert commands(env).none? { |args| args.first == 'bun' || args[0, 3] == %w[mise exec bun] }
    assert File.exist?("#{home}/.local/lib/archon/cli.rb")
    assert !File.exist?("#{home}/.local/lib/archon/commands/libs/README.md")
  end,
  'managed deletion rejects symlinks outside home' => lambda do |repo, home, _bin, env|
    outside = "#{repo}/outside"
    FileUtils.mkdir_p([outside, "#{home}/.config"])
    File.write("#{outside}/keep", 'safe')
    File.symlink(outside, "#{home}/.config/managed")
    _, error, status = run_setup(repo, env)
    assert status.exitstatus == 1
    assert error.include?('Invalid managed home directory')
    assert File.read("#{outside}/keep") == 'safe'
  end,
  'rootless setup needs no sudo or dependency installation on a second run' => lambda do |repo, home, _bin, env|
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    first_run_count = commands(env).length
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    second_run = commands(env).drop(first_run_count)
    assert second_run.none? { |args| args.first == 'sudo' }
    assert second_run.none? { |args| args[0, 3] == %w[omarchy pkg add] && (args & %w[rootlesskit slirp4netns]).any? }
    assert second_run.any? { |args| args.first == 'docker' && args.include?('info') }
    %w[subuid subgid].each do |file|
      assert File.read("#{env['SYSTEM_FIXTURE']}/#{file}") == "other:100000:65536\ndeveloper:165536:65536\n"
    end
    calls = commands(env)
    assert calls.count { |args| args.first == 'curl' } == 1
    assert calls.index { |args| args.first == 'docker' && args.include?('info') } < calls.index(%w[sudo systemctl disable --now docker.service docker.socket])
    assert calls.none? { |args| args.include?('aur') || args.include?('sudoless-docker') }
    assert File.executable?("#{home}/.local/lib/archon-docker/dockerd-rootless.sh")
    assert File.read("#{home}/.config/systemd/user/docker.service") == File.read("#{repo}/data/home/.config/systemd/user/docker.service")
  end,
  'rootless setup handles missing subid files and enabled but inactive rootful Docker' => lambda do |repo, _home, _bin, env|
    state = env.fetch('SYSTEM_FIXTURE')
    %w[subuid subgid].each { |file| File.unlink("#{state}/#{file}") }
    File.write("#{state}/is-active", 'no')
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    %w[subuid subgid].each do |file|
      assert File.read("#{state}/#{file}") == "developer:100000:65536\n"
      assert commands(env).include?(['sudo', 'touch', "/etc/#{file}"])
    end
    assert commands(env).include?(%w[sudo systemctl disable --now docker.service docker.socket])
  end,
  'rootless setup repairs changed state on later runs' => lambda do |repo, home, _bin, env|
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    first_run_count = commands(env).length
    state = env.fetch('SYSTEM_FIXTURE')
    File.unlink("#{state}/slirp4netns")
    File.write("#{state}/subuid", "other:100000:65536\ndeveloper:165536:1000\n")
    File.write("#{state}/linger", 'no')
    File.write("#{state}/is-active", 'yes')
    File.write("#{state}/groups", 'developer wheel docker')
    service = '.config/systemd/user/docker.service'
    File.write("#{repo}/data/home/#{service}", "[Service]\nExecStart=/updated-launcher\n")
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    later_calls = commands(env).drop(first_run_count)
    assert later_calls.include?(%w[omarchy pkg add slirp4netns])
    assert later_calls.select { |args| args.first == 'sudo' } == [
      %w[sudo usermod --add-subuids 166536-232071 developer],
      %w[sudo loginctl enable-linger developer],
      %w[sudo systemctl disable --now docker.service docker.socket],
      %w[sudo gpasswd -d developer docker]
    ]
    assert File.read("#{home}/#{service}") == File.read("#{repo}/data/home/#{service}")
  end,
  'launcher follows Docker upgrades without script edits' => lambda do |repo, home, _bin, env|
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    _, error, status = run_setup(repo, env.merge('DOCKER_VERSION' => '30.0.0'))
    assert status.success?, error
    downloads = commands(env).select { |args| args.first == 'curl' }
    assert downloads.length == 2
    assert downloads.last.any? { |arg| arg.include?('/docker-v30.0.0/') }
    assert File.read("#{home}/.local/lib/archon-docker/version").strip == '30.0.0'
  end,
  'corrupted launcher download fails before changing services' => lambda do |repo, home, _bin, env|
    _, error, status = run_setup(repo, env.merge('BAD_DOWNLOAD' => '1'))
    assert status.exitstatus == 1
    assert error.include?('failed')
    assert !File.exist?("#{home}/.local/lib/archon-docker/dockerd-rootless.sh")
    assert commands(env).none? { |args| args.first == 'systemctl' && args.include?('docker.service') }
  end,
  'a rootful response fails before disabling the old daemon' => lambda do |repo, _home, _bin, env|
    _, error, status = run_setup(repo, env.merge('ROOTFUL_DOCKER' => '1'))
    assert status.exitstatus == 1
    assert error.include?('did not start in rootless mode')
    assert !commands(env).include?(%w[sudo systemctl disable --now docker.service docker.socket])
  end,
  'Bash and the desktop session use the same rootless socket' => lambda do |_repo, _home, _bin, _env|
    config = File.expand_path('../../data/home/.config', __dir__)
    %w[archon/bashrc uwsm/env.d/20-archon-docker.sh].each do |file|
      output, error, status = Open3.capture3(
        { 'XDG_CONFIG_HOME' => config, 'XDG_RUNTIME_DIR' => '/run/user/1000', 'DOCKER_HOST' => 'unix:///var/run/docker.sock' },
        '/bin/bash', '--noprofile', '--norc', '-c', '. "$1"; printf "%s" "$DOCKER_HOST"', 'bash', "#{config}/#{file}"
      )
      assert status.success?, error
      assert output == 'unix:///run/user/1000/docker.sock'
    end
  end,
  'CLI installation does not need Bun on PATH' => lambda do |repo, home, bin, env|
    File.unlink("#{bin}/bun")
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    assert commands(env).none? { |args| args == %w[omarchy install dev-env bun] }
    assert commands(env).none? { |args| args.first == 'bun' || args[0, 3] == %w[mise exec bun] }
    assert File.exist?("#{home}/.local/lib/archon/cli.rb")
  end
}

checks.each do |name, check|
  fixture(&check)
  puts "PASS #{name}"
end
puts "#{checks.length} checks passed"
