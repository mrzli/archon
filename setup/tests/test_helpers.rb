require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

REPO_ROOT = File.expand_path('../..', __dir__)
FIXTURE_COMMANDS = {
  applications: %w[omarchy pacman],
  cli: %w[rsync],
  codex: %w[codex],
  docker: %w[omarchy pacman id cat test sudo curl docker systemctl loginctl],
  files: %w[rsync],
  skills: %w[git],
  tools: %w[omarchy mise rails uv node bun zls pnpm go],
  voice: %w[omarchy voxtype sudo systemctl]
}.freeze
$checks = 0

def assert(condition, message = 'assertion failed')
  raise message unless condition
end

def check(name, area, &block)
  fixture(area, &block)
  $checks += 1
  puts "PASS #{name}"
end

def fixture(area)
  Dir.mktmpdir('archon-setup-') do |root|
    repo = "#{root}/repo with spaces"
    home = "#{root}/home"
    bin = "#{root}/bin"
    FileUtils.mkdir_p(["#{repo}/setup", home, bin])
    FileUtils.cp("#{REPO_ROOT}/setup.sh", repo)
    FileUtils.cp(Dir["#{REPO_ROOT}/setup/*.rb"], "#{repo}/setup")
    areas = area == :full ? FIXTURE_COMMANDS.keys : area == :none ? [] : [area]
    (areas & %i[cli docker files tools voice]).each { |name| send("prepare_#{name}", repo, home, root) }
    stub = "#!#{RbConfig.ruby}\n#{File.read(File.join(__dir__, 'commands.rb'))}"
    commands = areas.flat_map { |name| FIXTURE_COMMANDS.fetch(name) }.uniq
    commands.concat(%w[code hyprctl]) if area == :full
    commands.each do |command|
      File.write("#{bin}/#{command}", stub)
      File.chmod(0o755, "#{bin}/#{command}")
    end
    %w[realpath dirname].each { |command| File.symlink("/usr/bin/#{command}", "#{bin}/#{command}") }
    env = { 'HOME' => home, 'XDG_DATA_HOME' => "#{home}/.local/share", 'PATH' => bin,
            'XDG_CONFIG_HOME' => "#{home}/.config", 'XDG_STATE_HOME' => "#{home}/.local/state",
            'XDG_RUNTIME_DIR' => "#{root}/run", 'COMMAND_LOG' => "#{root}/commands.jsonl",
            'SYSTEM_FIXTURE' => root, 'OMARCHY_PATH' => "#{root}/omarchy" }
    yield repo, home, bin, env
  end
end

def prepare_cli(repo, _home, _root)
  FileUtils.mkdir_p("#{repo}/components/archon-cli")
  %w[bin lib].each do |directory|
    FileUtils.cp_r("#{REPO_ROOT}/components/archon-cli/#{directory}", "#{repo}/components/archon-cli/")
  end
end

def prepare_docker(_repo, _home, root)
  %w[subuid subgid].each { |file| File.write("#{root}/#{file}", "other:100000:65536\n") }
  { 'linger' => 'no', 'is-enabled' => 'yes', 'is-active' => 'yes', 'groups' => 'developer wheel docker' }.each do |property, value|
    File.write("#{root}/#{property}", value)
  end
end

def prepare_files(repo, home, _root)
  FileUtils.mkdir_p("#{repo}/data/home/.config/systemd/user/voxtype.service.d")
  %w[docker.service voxtype.service.d/10-archon.conf].each do |file|
    relative = "data/home/.config/systemd/user/#{file}"
    FileUtils.cp("#{REPO_ROOT}/#{relative}", "#{repo}/#{relative}")
  end
  FileUtils.cp("#{REPO_ROOT}/data/home-copy-ignore.txt", "#{repo}/data/home-copy-ignore.txt")
  File.write("#{repo}/data/home-replace-directories.txt", ".config/managed\n")
  File.write("#{repo}/data/home/managed-file", "managed\n")
  File.write("#{home}/personal-file", "preserve\n")
  FileUtils.mkdir_p("#{home}/.config/hypr")
  File.write("#{home}/.config/hypr/hyprland.lua", "-- existing user configuration\n")
end

def prepare_tools(repo, _home, root)
  mise_tools = %w[ruby python node bun zig zls pnpm go].to_h do |tool|
    [tool, [{ 'version' => '1.0', 'installed' => true }]]
  end
  File.write("#{root}/mise-tools.json", JSON.generate(mise_tools))
  FileUtils.mkdir_p("#{repo}/data")
  File.write("#{repo}/data/vscode-extensions.txt", "# extensions\nexisting.extension\nnew.extension\n")
end

def prepare_voice(_repo, _home, root)
  File.write("#{root}/voice-variant", 'whisper-avx2')
  FileUtils.mkdir_p("#{root}/omarchy/default/voxtype")
  File.write("#{root}/omarchy/default/voxtype/config.toml", "[hotkey]\nenabled = false\n")
  File.write("#{root}/voice-config.json", JSON.generate({
    'engine' => 'whisper', 'whisper.model' => 'base.en', 'whisper.mode' => 'local',
    'whisper.language' => 'en', 'audio.device' => 'my microphone', 'hotkey.enabled' => false,
    'whisper.gpu_isolation' => true, 'whisper.on_demand_loading' => true, 'whisper.gpu_device' => 1
  }))
end

def run_setup(repo, env, *arguments)
  Open3.capture3(env, RbConfig.ruby, "#{repo}/setup/main.rb", *arguments)
end

def run_operation(repo, env, operation)
  code = <<~RUBY
    repo = ARGV.fetch(0)
    home = ENV.fetch('HOME')
    begin
      #{operation}
    rescue StandardError => error
      warn error.message
      exit 1
    end
  RUBY
  Open3.capture3(env, RbConfig.ruby, '-r', "#{repo}/setup/setup.rb", '-e', code, repo)
end

def commands(env)
  File.exist?(env['COMMAND_LOG']) ? File.readlines(env['COMMAND_LOG']).map { |line| JSON.parse(line) } : []
end
