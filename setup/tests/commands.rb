require 'rbconfig'
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
      edits = request.fetch('params').fetch('edits')
      File.write("#{state}/codex-edits.json", JSON.generate(edits))
    end
    puts JSON.generate({ id: request['id'], result: {} })
    STDOUT.flush
  end
when 'id'
  puts(ARGV.first == '-un' ? 'developer' : ARGV.first == '-u' ? '1000' : File.read("#{state}/groups"))
when 'cat'
  puts File.read(File.join(ENV.fetch('SYSTEM_FIXTURE'), File.basename(ARGV.first)))
when 'test'
  exit(File.exist?(File.join(state, File.basename(ARGV.last))) ? 0 : 1)
when 'pacman'
  if %w[rootlesskit slirp4netns].include?(ARGV.last)
    exit(File.exist?("#{state}/#{ARGV.last}") ? 0 : 1)
  end
when 'omarchy'
  if ARGV[0, 2] == %w[install dev-env]
    tools = JSON.parse(File.read("#{state}/mise-tools.json"))
    names = ARGV.last == 'zig' ? %w[zig zls] : [ARGV.last]
    names.each { |tool| tools[tool] = [{ 'version' => '1.0', 'installed' => true }] }
    File.write("#{state}/mise-tools.json", JSON.generate(tools))
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
    (ARGV & %w[rootlesskit slirp4netns]).each { |package| FileUtils.touch("#{state}/#{package}") }
  end
when 'voxtype'
  case ARGV[0, 2]
  when %w[info variants]
    puts JSON.generate({ 'active_variant' => File.read("#{state}/voice-variant"),
                         'variants' => [{ 'binary_name' => 'voxtype-vulkan', 'installed' => !ENV['NO_VULKAN'] }] })
  when %w[setup --download]
    exit 1 if ENV['FAIL_VOICE_DOWNLOAD']
  when %w[config get]
    puts File.read("#{state}/voice-config.json")
  when %w[config set]
    config = JSON.parse(File.read("#{state}/voice-config.json"))
    config[ARGV[2]] = begin
      JSON.parse(ARGV[3])
    rescue JSON::ParserError
      ARGV[3]
    end
    File.write("#{state}/voice-config.json", JSON.generate(config))
  end
when 'loginctl'
  puts File.read("#{state}/linger")
when 'systemctl'
  if %w[is-enabled is-active].include?(ARGV.first)
    exit(File.read("#{state}/#{ARGV.first}").strip == 'yes' ? 0 : 1)
  end
when 'sudo'
  if ARGV[0, 3] == %w[voxtype setup variant]
    File.write("#{state}/voice-variant", 'whisper-vulkan')
  elsif ARGV.first == 'touch'
    FileUtils.touch(File.join(state, File.basename(ARGV.last)))
  elsif ARGV.first == 'loginctl'
    File.write("#{state}/linger", 'yes')
  elsif ARGV.first == 'systemctl'
    %w[is-enabled is-active].each { |property| File.write("#{state}/#{property}", 'no') }
  elsif ARGV.first == 'gpasswd'
    File.write("#{state}/groups", 'developer wheel')
  elsif ARGV.first == 'usermod'
    kind = ARGV[1].delete_prefix('--add-sub').delete_suffix('s')
    first = ARGV[2].split('-').first
    File.open("#{ENV.fetch('SYSTEM_FIXTURE')}/sub#{kind}", 'a') do |file|
      file.puts "#{ARGV[3]}:#{first}:65536"
    end
  end
when 'curl'
  File.write(ARGV.last, ENV['BAD_DOWNLOAD'] ? '(' : "#!/bin/sh\nexit 0\n")
when 'docker'
  if ARGV == ['--version']
    puts "Docker version #{ENV.fetch('DOCKER_VERSION', '29.7.2')}, build fixture"
    exit 0
  end
  puts JSON.generate(ENV['ROOTFUL_DOCKER'] ? ['name=seccomp'] : ['name=seccomp', 'name=rootless'])
when 'code'
  puts 'EXISTING.extension' if ARGV.first == '--list-extensions'
when 'git'
  if ARGV.include?('clone')
    FileUtils.mkdir_p(["#{ARGV.last}/.git", "#{ARGV.last}/skills/productivity/example"])
    File.write("#{ARGV.last}/skills/productivity/example/SKILL.md", 'example skill')
  end
when 'rsync'
  exec '/usr/bin/rsync', *ARGV
when 'mise'
  tools = JSON.parse(File.read("#{state}/mise-tools.json"))
  if ARGV[0, 4] == %w[ls --global --installed --json]
    puts JSON.generate(tools.fetch(ARGV.last, []).select { |version| version['installed'] })
  elsif ARGV[0, 2] == %w[use --global]
    tools[ARGV.last] = [{ 'version' => '1.0', 'installed' => true }]
    File.write("#{state}/mise-tools.json", JSON.generate(tools))
  end
  if ARGV[0, 3] == %w[exec ruby --]
    exec RbConfig.ruby, *ARGV.drop(4)
  end
end
