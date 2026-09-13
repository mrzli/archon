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
    %w[setup.sh setup/main.rb setup/setup.rb].each do |file|
      FileUtils.cp(File.expand_path("../../#{file}", __dir__), "#{repo}/#{file}")
    end
    File.write("#{repo}/data/vscode-extensions.txt", "# extensions\nexisting.extension\nnew.extension\n")
    File.write("#{repo}/data/home-copy-ignore.txt", '')
    File.write("#{repo}/data/home-replace-directories.txt", ".config/managed\n")
    File.write("#{repo}/data/home/managed-file", "managed\n")
    File.write("#{home}/personal-file", "preserve\n")
    stub = <<~SCRIPT
      #!#{RbConfig.ruby}
      require 'fileutils'
      require 'json'
      name = File.basename($0)
      File.open(ENV.fetch('COMMAND_LOG'), 'a') { |file| file.puts(JSON.generate([name, *ARGV])) }
      exit 1 if ENV['FAIL_COMMAND'] == name
      case name
      when 'code'
        puts 'EXISTING.extension' if ARGV.first == '--list-extensions'
      when 'git'
        FileUtils.mkdir_p("\#{ARGV.last}/.git") if ARGV.include?('clone')
      when 'rsync'
        exit 0 if ARGV[-2].include?('archon-skills')
        exec '/usr/bin/rsync', *ARGV
      when 'bun'
        if ARGV.first.end_with?('/build.ts')
          exit 1 if ENV['FAIL_BUILD']
          dist = File.expand_path('../dist', File.dirname(ARGV.first))
          FileUtils.mkdir_p(dist)
          File.write("\#{dist}/cli-marker", 'built')
        end
      when 'mise'
        if ARGV[0, 3] == %w[exec ruby --]
          exec #{RbConfig.ruby.inspect}, *ARGV.drop(4)
        elsif ARGV[0, 3] == %w[exec bun --]
          exec ENV.fetch('BUN_STUB'), *ARGV.drop(4)
        end
      end
    SCRIPT
    %w[omarchy pacman code git rsync hyprctl mise rails uv node bun zls pnpm go].each do |command|
      File.write("#{bin}/#{command}", stub)
      File.chmod(0o755, "#{bin}/#{command}")
    end
    %w[realpath dirname].each { |command| File.symlink("/usr/bin/#{command}", "#{bin}/#{command}") }
    env = { 'HOME' => home, 'XDG_DATA_HOME' => "#{home}/.local/share", 'PATH' => bin,
            'COMMAND_LOG' => "#{root}/commands.jsonl" }
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
    assert File.read("#{home}/.local/cli-marker") == 'built'
    assert JSON.parse(File.read("#{home}/.config/nvim/lazyvim.json"))['extras'] == ['lazyvim.plugins.extras.util.rest']
    assert File.read("#{home}/.bashrc").scan('source ').length == 1
    assert commands(env).none? { |args| args.include?('existing.extension') }
    assert commands(env).count { |args| args.include?('clone') } == 1
    assert commands(env).count { |args| args.include?('pull') } == 1
  end,
  'failed commands stop setup' => lambda do |repo, _home, _bin, env|
    assert run_setup(repo, env.merge('FAIL_COMMAND' => 'omarchy')).last.exitstatus == 1
    assert commands(env) == [%w[omarchy pkg drop aether obsidian]]
  end,
  'build failure prevents CLI installation' => lambda do |repo, _home, _bin, env|
    assert run_setup(repo, env.merge('FAIL_BUILD' => '1')).last.exitstatus == 1
    assert commands(env).none? { |args| args.any? { |arg| arg.include?('/dist/') } }
    assert commands(env).none? { |args| args.first == 'git' }
  end,
  'managed deletion rejects symlinks outside home' => lambda do |repo, home, _bin, env|
    outside = "#{repo}/outside"
    FileUtils.mkdir_p([outside, "#{home}/.config"])
    File.write("#{outside}/keep", 'safe')
    File.symlink(outside, "#{home}/.config/managed")
    _, error, status = run_setup(repo, env, '-d')
    assert status.exitstatus == 1
    assert error.include?('Invalid managed home directory')
    assert File.read("#{outside}/keep") == 'safe'
  end,
  'newly installed Bun is reached through mise' => lambda do |repo, home, bin, env|
    # Keep the stub's basename so it still simulates Bun, but remove it from PATH.
    FileUtils.mkdir_p("#{repo}/runtime")
    FileUtils.mv("#{bin}/bun", "#{repo}/runtime/bun")
    _, error, status = run_setup(repo, env.merge('BUN_STUB' => "#{repo}/runtime/bun"))
    assert status.success?, error
    assert commands(env).include?(%w[omarchy install dev-env bun])
    assert commands(env).any? { |args| args[0, 4] == %w[mise exec bun --] }
    assert File.read("#{home}/.local/cli-marker") == 'built'
  end
}

checks.each do |name, check|
  fixture(&check)
  puts "PASS #{name}"
end
puts "#{checks.length} checks passed"
