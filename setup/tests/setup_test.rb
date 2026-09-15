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
        STDIN.each_line do |line|
          request = JSON.parse(line)
          next unless request.key?('id')

          if request['method'] == 'config/batchWrite'
            File.write("\#{state}/codex-edits.json", JSON.generate(request.fetch('params').fetch('edits')))
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
        if ARGV == %w[voxtype install]
          File.symlink($0, File.join(File.dirname($0), 'voxtype'))
        end
        if ARGV[0, 2] == %w[pkg add]
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
        FileUtils.mkdir_p("\#{ARGV.last}/.git") if ARGV.include?('clone')
      when 'rsync'
        exit 0 if ARGV[-2].include?('archon-skills')
        exec '/usr/bin/rsync', *ARGV
      when 'mise'
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
            'COMMAND_LOG' => "#{root}/commands.jsonl", 'SYSTEM_FIXTURE' => root }
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
    2.times do
      _, error, status = run_setup(repo, env)
      assert status.success?, error
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
  'voice AI uses the Omarchy installer and skips an existing installation' => lambda do |repo, _home, _bin, env|
    _, error, status = run_setup(repo, env)
    assert status.success?, error
    assert commands(env).count { |args| args == %w[omarchy voxtype install] } == 1

    _, error, status = run_setup(repo, env)
    assert status.success?, error
    assert commands(env).count { |args| args == %w[omarchy voxtype install] } == 1
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
  'setup provisions only the requested Codex navigation bindings' => lambda do |repo, _home, _bin, env|
    2.times do
      _, error, status = run_setup(repo, env)
      assert status.success?, error
    end
    edits = JSON.parse(File.read("#{env.fetch('SYSTEM_FIXTURE')}/codex-edits.json"))
    assert edits == [
      { 'keyPath' => 'tui.keymap.chat.edit_queued_message', 'value' => 'alt-shift-up', 'mergeStrategy' => 'replace' },
      { 'keyPath' => 'tui.keymap.chat.prompt_stack_back', 'value' => 'alt-shift-down', 'mergeStrategy' => 'replace' }
    ]
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
    assert commands(env).include?(%w[omarchy install dev-env bun])
    assert commands(env).none? { |args| args.first == 'bun' || args[0, 3] == %w[mise exec bun] }
    assert File.exist?("#{home}/.local/lib/archon/cli.rb")
  end
}

checks.each do |name, check|
  fixture(&check)
  puts "PASS #{name}"
end
puts "#{checks.length} checks passed"
