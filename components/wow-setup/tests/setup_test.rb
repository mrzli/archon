require 'fileutils'
require 'digest'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

SCRIPT = File.expand_path('../setup.sh', __dir__)
PINNED_INSTALLER = File.expand_path('../install-pinned-addon.sh', __dir__)
GAME_ROOT = 'Games/battlenet/drive_c/Program Files (x86)/World of Warcraft'

RETAIL_ADDONS = %w[
  github:ATTWoWAddon/AllTheThings wowi:24680
  wowi:25631 wowi:25784 wowi:25552 wowi:25547 wowi:25553 wowi:24770
  wowi:25792 wowi:25655 wowi:26399 wowi:26776
  wowi:24769 wowi:25660 wowi:26458
  github:Nevcairiel/HandyNotes
  wowi:26818 wowi:26817 wowi:26816 wowi:26815 wowi:26814 wowi:26813
  wowi:26812 wowi:25829 wowi:25828 wowi:26409 wowi:26753 wowi:27067
  github:Nevcairiel/GatherMate2 github:Nevcairiel/GatherMate2_Data
  github:DeadlyBossMods/DeadlyBossMods
  github:EllesmereGaming/EllesmereUI
].freeze

FOREVER_ADDONS = %w[
  github:Questie/Questie
  github:Nevcairiel/HandyNotes github:kemayo/wow-handynotes-forever
  github:Nevcairiel/GatherMate2
  github:DeadlyBossMods/DeadlyBossMods github:DeadlyBossMods/DBM-Vanilla github:DeadlyBossMods/DBM-Dungeons
  github:EllesmereGaming/EllesmereUI
  github:funkydude/BugSack
].freeze

def assert(value, message = 'assertion failed')
  raise message unless value
end

def write_archive(path, folder)
  _, error, status = Open3.capture3('python3', '-c', <<~PYTHON, path, folder)
    import sys, zipfile
    with zipfile.ZipFile(sys.argv[1], 'w') as archive:
        archive.writestr(sys.argv[2] + '/' + sys.argv[2] + '.toc', '## Interface: 16001\\n')
  PYTHON
  assert status.success?, error
end

def pinned_sha(source, folder)
  source[/\('?#{Regexp.escape(folder)}'? .*?\n\s+\S+\n\s+(\h{64})\)/m, 1] || raise("no pin for #{folder}")
end

def fixture(games: %w[retail forever])
  Dir.mktmpdir('wow-addons-test-') do |root|
    home = "#{root}/home"
    bin = "#{root}/bin"
    dirs = games.to_h { |game| [game, "#{home}/#{GAME_ROOT}/_#{game}_"] }
    dirs.each_value do |dir|
      FileUtils.mkdir_p([bin, "#{dir}/Interface/AddOns/Personal", "#{dir}/WTF"])
      File.write("#{dir}/Wow.exe", '')
      File.write("#{dir}/Interface/AddOns/Personal/keep", 'personal addon')
      File.write("#{dir}/WTF/keep", 'personal settings')
    end
    FileUtils.mkdir_p(bin)
    archives = { 'Auctionator' => "#{root}/auctionator.zip", '!BugGrabber' => "#{root}/buggrabber.zip" }
    source = File.read(SCRIPT)
    archives.each do |folder, archive|
      if folder == 'Auctionator' && ENV['AUCTIONATOR_TEST_ARCHIVE']
        FileUtils.cp(ENV.fetch('AUCTIONATOR_TEST_ARCHIVE'), archive)
        next
      end
      write_archive(archive, folder)
      source = source.sub(pinned_sha(source, folder), Digest::SHA256.file(archive).hexdigest)
    end
    script = "#{root}/setup.sh"
    File.write(script, source)
    FileUtils.cp(PINNED_INSTALLER, "#{root}/install-pinned-addon.sh")
    stub = <<~'RUBY'
      require 'fileutils'
      require 'json'
      name = File.basename($0)
      File.open(ENV.fetch('COMMAND_LOG'), 'a') { |f| f.puts(JSON.generate([name, *ARGV])) }
      exit 1 if ENV['FAIL_COMMAND'] == name
      case name
      when 'curl'
        output = ARGV.fetch(ARGV.index('-o') + 1)
        if ENV['CORRUPT_DOWNLOAD']
          File.write(output, 'invalid download')
        else
          archive = ARGV.any? { |arg| arg.include?('BugGrabber') } ? 'BUGGRABBER_ARCHIVE' : 'AUCTIONATOR_ARCHIVE'
          FileUtils.cp(ENV.fetch(archive), output)
        end
      when 'uv'
        abort 'unexpected uv command' unless ARGV == %w[tool install --upgrade instawow]
        FileUtils.mkdir_p(ENV.fetch('UV_TOOL_BIN_DIR'))
        FileUtils.cp("#{ENV.fetch('STUB_BIN')}/instawow", "#{ENV.fetch('UV_TOOL_BIN_DIR')}/instawow")
      when 'instawow'
        flavours = { 'wow-retail' => 'retail', 'wow-forever' => 'forever_classic' }
        options = ARGV.shift(4)
        abort 'unexpected options' unless options[0, 3] == %w[--no-cache -v -p]
        profile = options[3]
        abort 'unexpected profile' unless flavours.key?(profile)
        state_file = "#{ENV.fetch('HOME')}/addons-#{profile}.json"
        state = File.exist?(state_file) ? JSON.parse(File.read(state_file)) : {}
        case ARGV.shift
        when 'configure'
          path = ARGV.first.delete_prefix('addon_dir=')
          abort 'missing addon directory' unless File.directory?(path)
          abort 'wrong game directory' unless path.include?(profile == 'wow-retail' ? '/_retail_/' : '/_forever_/')
          abort 'wrong flavour' unless ARGV.last == "flavour_override=#{flavours.fetch(profile)}"
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
    %w[uv instawow curl].each do |name|
      File.write("#{bin}/#{name}", "#!#{RbConfig.ruby}\n#{stub}")
      File.chmod(0o755, "#{bin}/#{name}")
    end
    env = { 'HOME' => home, 'PATH' => "#{bin}:/usr/bin:/bin", 'STUB_BIN' => bin,
            'COMMAND_LOG' => "#{root}/commands.jsonl",
            'AUCTIONATOR_ARCHIVE' => archives['Auctionator'], 'BUGGRABBER_ARCHIVE' => archives['!BugGrabber'] }
    run = ->(*args, **extra) { Open3.capture3(env.merge(extra), '/bin/bash', script, *args) }
    run_pinned = lambda do |game_dir, folder, **extra|
      sha = Digest::SHA256.file(archives.fetch(folder)).hexdigest
      Open3.capture3(env.merge(extra), '/bin/bash', "#{root}/install-pinned-addon.sh",
                     game_dir, folder, 'test', "https://example.invalid/#{folder}.zip", sha)
    end
    yield home, dirs, env, run, run_pinned
  end
end

def calls(env)
  return [] unless File.exist?(env.fetch('COMMAND_LOG'))

  File.readlines(env.fetch('COMMAND_LOG')).map { |line| JSON.parse(line) }
end

def state(home, profile)
  file = "#{home}/addons-#{profile}.json"
  File.exist?(file) ? JSON.parse(File.read(file)) : nil
end

def assert_preserved(dir)
  assert File.read("#{dir}/Interface/AddOns/Personal/keep") == 'personal addon'
  assert File.read("#{dir}/WTF/keep") == 'personal settings'
end

fixture do |_home, dirs, env, run|
  assert run.call('--help').last.success?
  assert run.call('--unknown').last.exitstatus == 2
  assert run.call('--retail-dir').last.exitstatus == 2
  assert run.call('--forever-dir', '').last.exitstatus == 2
  _, error, status = run.call('--retail-dir', '/missing')
  assert status.exitstatus == 1 && error.include?('Retail WoW not found at /missing.')
  _, error, status = run.call('--forever-dir', '/missing', '--retail-dir', dirs.fetch('retail'))
  assert status.exitstatus == 1 && error.include?('WoW Forever not found at /missing.')
  assert calls(env).empty?, 'argument validation must precede installation'
  puts 'PASS argument validation, including explicit missing directories'
end

fixture do |home, dirs, env, run|
  [1, 2, 2].each do |version|
    dirs.each_value do |dir|
      auctionator = "#{dir}/Interface/AddOns/Auctionator"
      File.write("#{auctionator}/obsolete.lua", 'old code') if File.directory?(auctionator)
    end
    output, error, status = run.call(**{ 'ADDON_VERSION' => version.to_s })
    assert status.success?, error
    assert output.include?('Installing Auctionator 339 (pinned')
    assert output.include?('Installing !BugGrabber v12.1.1 (pinned')
    dirs.each_value do |dir|
      auctionator = "#{dir}/Interface/AddOns/Auctionator"
      assert !Dir["#{auctionator}/*.toc"].empty?
      assert !File.exist?("#{auctionator}/obsolete.lua"), 'replacement must remove stale addon code'
      assert Dir["#{dir}/Interface/AddOns/.pinned-*"].empty?, 'temporary files must be cleaned up'
      assert_preserved(dir)
    end
  end
  assert Dir.exist?("#{dirs.fetch('forever')}/Interface/AddOns/!BugGrabber")
  assert !Dir.exist?("#{dirs.fetch('retail')}/Interface/AddOns/!BugGrabber"), 'BugGrabber is Forever only'
  { 'wow-retail' => RETAIL_ADDONS, 'wow-forever' => FOREVER_ADDONS }.each do |profile, expected|
    installed = state(home, profile)
    assert installed.keys.sort == expected.sort, "#{profile} must install exactly its add-ons"
    assert installed.values.all? { |version| version == 2 }, "rerun must update every #{profile} add-on"
    installs = calls(env).count { |call| call.first == 'instawow' && call[4] == profile && call[5] == 'install' }
    assert installs == expected.length, "#{profile} must install each add-on once"
  end
  puts 'PASS both games: install, updates, separate profiles, pins, paths with spaces, and preservation'
end

{ 'retail' => %w[wow-retail wow-forever], 'forever' => %w[wow-forever wow-retail] }.each do |game, (present, absent)|
  fixture(games: [game]) do |home, dirs, _env, run|
    output, error, status = run.call
    assert status.success?, error
    missing = game == 'retail' ? 'WoW Forever' : 'Retail WoW'
    assert error.include?("#{missing} not found at") && error.include?('skipping it.')
    assert !state(home, present).nil? && state(home, absent).nil?, 'only the installed game is set up'
    assert output.include?('GatherMate2 settings > Import') == (game == 'retail')
    assert_preserved(dirs.fetch(game))
  end
  puts "PASS only #{game} installed: the other game is skipped"
end

fixture(games: []) do |home, _dirs, _env, run|
  custom = { 'retail' => "#{home}/other games/_retail_", 'forever' => "#{home}/other games/_forever_" }
  custom.each_value do |dir|
    FileUtils.mkdir_p(dir)
    File.write("#{dir}/Wow.exe", '')
  end
  _, error, status = run.call('--retail-dir', custom.fetch('retail'), '--forever-dir', custom.fetch('forever'))
  assert status.success?, error
  assert !state(home, 'wow-retail').nil? && !state(home, 'wow-forever').nil?
  assert Dir.exist?("#{custom.fetch('retail')}/Interface/AddOns/Auctionator")
  assert Dir.exist?("#{custom.fetch('forever')}/Interface/AddOns/!BugGrabber")
  puts 'PASS directory options install into non-default paths'
end

fixture(games: []) do |_home, _dirs, env, run|
  _, error, status = run.call
  assert status.exitstatus == 1
  assert error.include?('No WoW installation found.')
  assert calls(env).empty?
  puts 'PASS no installed game stops before installation'
end

%w[download checksum].each do |failure|
  fixture(games: ['forever']) do |_home, dirs, _env, _run, run_pinned|
    addon = "#{dirs.fetch('forever')}/Interface/AddOns/!BugGrabber"
    FileUtils.mkdir_p(addon)
    File.write("#{addon}/keep", 'existing addon')
    extra = failure == 'download' ? { 'FAIL_COMMAND' => 'curl' } : { 'CORRUPT_DOWNLOAD' => '1' }
    assert !run_pinned.call(dirs.fetch('forever'), '!BugGrabber', **extra).last.success?
    assert File.read("#{addon}/keep") == 'existing addon', 'failed download must preserve existing addon'
    assert Dir["#{dirs.fetch('forever')}/Interface/AddOns/.pinned-*"].empty?
  end
  puts "PASS pinned add-on #{failure} failure preserves existing installation"
end

fixture do |_home, _dirs, env, run|
  _, error, status = run.call(**{ 'PATH' => '' })
  assert status.exitstatus == 1
  assert error.include?('uv is required but was not found on PATH.')
  assert calls(env).empty?
  puts 'PASS missing uv stops before installation'
end

%w[uv instawow].each do |command|
  fixture do |home, _dirs, env, run|
    assert run.call(**{ 'FAIL_COMMAND' => command }).last.exitstatus == 1
    assert calls(env).last.first == command, 'failure must stop subsequent commands'
    assert state(home, 'wow-retail').nil? && state(home, 'wow-forever').nil?
  end
  puts "PASS #{command} failure stops installation"
end
