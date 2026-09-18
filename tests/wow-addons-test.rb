require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

SCRIPT = File.expand_path('../install-wow-addons.sh', __dir__)

def assert(value, message = 'assertion failed')
  raise message unless value
end

def fixture
  Dir.mktmpdir('wow-addons-test-') do |root|
    home = "#{root}/home"
    bin = "#{root}/bin"
    wow = "#{home}/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_retail_"
    FileUtils.mkdir_p([bin, "#{wow}/Interface/AddOns/Personal", "#{wow}/WTF"])
    File.write("#{wow}/Wow.exe", '')
    File.write("#{wow}/Interface/AddOns/Personal/keep", 'personal addon')
    File.write("#{wow}/WTF/keep", 'personal settings')
    stub = <<~'RUBY'
      require 'fileutils'
      require 'json'
      name = File.basename($0)
      File.open(ENV.fetch('COMMAND_LOG'), 'a') { |f| f.puts(JSON.generate([name, *ARGV])) }
      exit 1 if ENV['FAIL_COMMAND'] == name
      case name
      when 'uv'
        abort 'unexpected uv command' unless ARGV == %w[tool install --upgrade instawow]
        FileUtils.mkdir_p(ENV.fetch('UV_TOOL_BIN_DIR'))
        FileUtils.cp("#{ENV.fetch('STUB_BIN')}/instawow", "#{ENV.fetch('UV_TOOL_BIN_DIR')}/instawow")
      when 'instawow'
        abort 'unexpected profile' unless ARGV.shift(4) == %w[--no-cache -v -p wow-retail]
        state_file = "#{ENV.fetch('HOME')}/addons.json"
        state = File.exist?(state_file) ? JSON.parse(File.read(state_file)) : {}
        case ARGV.shift
        when 'configure'
          path = ARGV.first.delete_prefix('addon_dir=')
          abort 'missing addon directory' unless File.directory?(path)
          abort 'wrong flavour' unless ARGV.last == 'flavour_override=retail'
        when 'list'
          puts ARGV.last if state.key?(ARGV.last)
        when 'install'
          abort 'already installed' if state.key?(ARGV.first)
          state[ARGV.first] = ENV.fetch('ADDON_VERSION', '1').to_i
          File.write(state_file, JSON.generate(state))
        when 'update'
          version = ENV.fetch('ADDON_VERSION', '1').to_i
          unless ARGV.empty?
            abort 'not installed' unless state.key?(ARGV.first)
            abort 'package is up to date' if state[ARGV.first] == version
          end
          (ARGV.empty? ? state.keys : ARGV).each { |addon| state[addon] = version }
          File.write(state_file, JSON.generate(state))
        else
          abort 'unexpected instawow command'
        end
      end
    RUBY
    %w[uv instawow].each do |name|
      File.write("#{bin}/#{name}", "#!#{RbConfig.ruby}\n#{stub}")
      File.chmod(0o755, "#{bin}/#{name}")
    end
    env = { 'HOME' => home, 'PATH' => "#{bin}:/usr/bin:/bin", 'STUB_BIN' => bin,
            'COMMAND_LOG' => "#{root}/commands.jsonl" }
    run = ->(*args, **extra) { Open3.capture3(env.merge(extra), '/bin/bash', SCRIPT, *args) }
    yield home, wow, env, run
  end
end

fixture do |home, wow, env, run|
  assert run.call('--help').last.success?
  assert run.call('--unknown').last.exitstatus == 2
  assert run.call('--wow-dir').last.exitstatus == 2
  assert run.call('--wow-dir', '/missing').last.exitstatus == 1
  assert !File.exist?(env.fetch('COMMAND_LOG')), 'argument validation must precede installation'

  [1, 2, 2].each do |version|
    _, error, status = run.call('--wow-dir', wow, **{ 'ADDON_VERSION' => version.to_s })
    assert status.success?, error
  end
  state = JSON.parse(File.read("#{home}/addons.json"))
  expected_addons = %w[
    github:ATTWoWAddon/AllTheThings wowi:24680
    wowi:25631 wowi:25784 wowi:25552 wowi:25547 wowi:25553 wowi:24770
    wowi:25792 wowi:25655 wowi:26399 wowi:26776
    wowi:24769 wowi:25660 wowi:26458
    github:Nevcairiel/HandyNotes wowi:27067 github:DeadlyBossMods/DeadlyBossMods
    github:EllesmereGaming/EllesmereUI
  ]
  assert state.keys.sort == expected_addons.sort, 'all requested addons and modules must be installed'
  assert state.values.all? { |version| version == 2 }, 'rerun must update every addon'
  assert state['github:DeadlyBossMods/DeadlyBossMods'] == 2
  calls = File.readlines(env.fetch('COMMAND_LOG')).map { |line| JSON.parse(line) }
  assert calls.count { |call| call.first == 'instawow' && call[5] == 'install' } == expected_addons.length
  assert File.read("#{wow}/Interface/AddOns/Personal/keep") == 'personal addon'
  assert File.read("#{wow}/WTF/keep") == 'personal settings'

  puts 'PASS fresh install, updates including DBM, paths with spaces, and preservation'
end

fixture do |_home, _wow, env, run|
  _, error, status = run.call(**{ 'PATH' => '' })
  assert status.exitstatus == 1
  assert error.include?('uv is required but was not found on PATH.')
  assert !File.exist?(env.fetch('COMMAND_LOG'))
  puts 'PASS missing uv stops before installation'
end

%w[uv instawow].each do |command|
  fixture do |home, _wow, env, run|
    assert run.call(**{ 'FAIL_COMMAND' => command }).last.exitstatus == 1
    calls = File.readlines(env.fetch('COMMAND_LOG')).map { |line| JSON.parse(line) }
    assert calls.last.first == command, 'failure must stop subsequent commands'
    assert !File.exist?("#{home}/addons.json")
  end
  puts "PASS #{command} failure stops installation"
end
