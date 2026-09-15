require 'tmpdir'
require_relative '../workarounds'

def assert(condition)
  raise 'assertion failed' unless condition
end

Dir.mktmpdir('archon-video-') do |root|
  home = File.join(root, 'home')
  drm = File.join(root, 'drm')
  directory = File.join(home, '.config/hypr')
  FileUtils.mkdir_p(directory)
  config_path = File.join(directory, 'hyprland.lua')
  override_path = File.join(directory, 'archon_intel_video.lua')
  original = "-- user settings\nhl.env(\"OTHER_SETTING\", \"preserve\")\n"
  File.write(config_path, original)
  calls = []
  runner = ->(*args) { calls << args }
  gpu = lambda do |card, vendor|
    path = File.join(drm, card, 'device')
    FileUtils.mkdir_p(path)
    File.write(File.join(path, 'vendor'), "#{vendor}\n")
  end

  # NVIDIA-only and AMD/NVIDIA machines receive neither a package nor an override.
  gpu.call('card7', '0x10de')
  IntelVideoWorkaround.apply(home, drm_root: drm, runner: runner)
  gpu.call('card3', '0x1002')
  IntelVideoWorkaround.apply(home, drm_root: drm, runner: runner)
  assert(calls.empty? && File.read(config_path) == original && !File.exist?(override_path))

  gpu.call('card3', '0x8086')
  # A failed installation must not leave the Intel override enabled.
  begin
    IntelVideoWorkaround.apply(home, drm_root: drm, runner: ->(*) { raise 'install failed' })
    raise 'expected failure'
  rescue RuntimeError => error
    raise unless error.message == 'install failed'
  end
  assert(File.read(config_path) == original && !File.exist?(override_path))

  2.times { IntelVideoWorkaround.apply(home, drm_root: drm, runner: runner) }
  assert(calls == Array.new(2) { %w[omarchy pkg add intel-media-driver] })
  assert(File.read(config_path) == original + IntelVideoWorkaround::LOAD_LINE + "\n")
  assert(File.read("#{config_path}.before-archon-intel-video") == original)
  # Execute the generated Lua with a fake Hyprland API; only video decoding changes.
  system('lua', '-e', 'hl = {env = function(k,v) assert(k == "LIBVA_DRIVER_NAME" and v == "iHD") end}',
         override_path, exception: true)
  File.open(config_path, 'a') { |file| file.puts('-- later user edit') }
  2.times { IntelVideoWorkaround.remove(home) }
  assert(File.read(config_path) == original + "-- later user edit\n")
  assert(!File.exist?(override_path) && calls.length == 2)

  File.write(override_path, '-- unrelated user file')
  %i[apply remove].each do |action|
    begin
      if action == :apply
        IntelVideoWorkaround.apply(home, drm_root: drm, runner: runner)
      else
        IntelVideoWorkaround.remove(home)
      end
      raise 'expected refusal'
    rescue RuntimeError => error
      raise unless error.message.include?('unrecognized override')
    end
  end
  assert(File.read(override_path) == '-- unrelated user file')
end

puts 'PASS Intel video workaround: hardware selection, repeated apply/remove, failure safety, Lua, and preservation'
