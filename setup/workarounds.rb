require 'fileutils'
require_relative 'helpers'

module IntelVideoWorkaround
  extend self

  # Temporary workaround: https://github.com/omacom/omarchy/issues/8215
  # Apply independently: ruby setup/workarounds.rb apply intel-video
  # Retire: remove the apply call in setup.rb, then run:
  #   ruby setup/workarounds.rb remove intel-video
  # Log out/in and verify playback after removal, then delete this module.
  # The Intel driver is normal hardware support and is intentionally retained.
  LOAD_LINE = 'require("hypr.archon_intel_video") -- Archon temporary Intel video workaround'.freeze
  OVERRIDE = <<~LUA.freeze
    -- Temporary Intel/NVIDIA video decoding workaround, managed by Archon.
    -- https://github.com/omacom/omarchy/issues/8215
    hl.env("LIBVA_DRIVER_NAME", "iHD")
  LUA

  def applicable?(drm_root: '/sys/class/drm')
    vendors = Dir.glob("#{drm_root}/card[0-9]*/device/vendor").map { |path| File.read(path).strip }
    vendors.include?('0x8086') && vendors.include?('0x10de')
  end

  def apply(home, drm_root: '/sys/class/drm', runner: method(:run))
    return log_info('Intel/NVIDIA video workaround does not apply; skipping') unless applicable?(drm_root: drm_root)

    log_step 'Applying Intel/NVIDIA video decoding workaround'
    directory = File.join(home, '.config/hypr')
    config_path = File.join(directory, 'hyprland.lua')
    override_path = File.join(directory, 'archon_intel_video.lua')
    config = File.read(config_path)
    check_override(override_path)
    runner.call('omarchy', 'pkg', 'add', 'intel-media-driver')
    File.write(override_path, OVERRIDE) unless File.exist?(override_path)
    # remove deletes this line again, so no backup of the user's configuration is needed.
    unless config.lines.map(&:chomp).include?(LOAD_LINE)
      File.write(config_path, config + (config.end_with?("\n") ? '' : "\n") + LOAD_LINE + "\n")
    end
    log_info 'Intel video decoding configured. Log out/in before testing existing applications.'
  end

  def remove(home)
    directory = File.join(home, '.config/hypr')
    config_path = File.join(directory, 'hyprland.lua')
    override_path = File.join(directory, 'archon_intel_video.lua')
    check_override(override_path)
    if File.exist?(config_path)
      config = File.read(config_path)
      updated = config.lines.reject { |line| line.chomp == LOAD_LINE }.join
      File.write(config_path, updated) unless updated == config
    end
    FileUtils.rm_f(override_path)
    # Earlier versions of apply left this backup behind.
    FileUtils.rm_f("#{config_path}.before-archon-intel-video")
    log_info 'Intel video override removed; driver retained. Log out/in to clear the old environment.'
  end

  def check_override(path)
    if File.symlink?(path) || (File.exist?(path) && File.read(path) != OVERRIDE)
      raise "Refusing to change an unrecognized override: #{path}"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    unless [%w[apply intel-video], %w[remove intel-video]].include?(ARGV)
      warn 'Usage: ruby setup/workarounds.rb <apply|remove> intel-video'
      exit 2
    end
    if ARGV.first == 'remove' || IntelVideoWorkaround.applicable?
      IntelVideoWorkaround.public_send(ARGV.first, Dir.home)
      run 'hyprctl', 'reload'
      run 'hyprctl', 'configerrors'
    else
      log_info 'Intel/NVIDIA video workaround does not apply; skipping'
    end
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
