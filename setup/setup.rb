require 'fileutils'
require 'json'
require_relative 'helpers'
require_relative 'docker'
require_relative 'codex'
require_relative 'workarounds'

def setup
  return unless parse_options

  repo_root = File.expand_path('..', __dir__)
  home = ENV.fetch('HOME')

  remove_unwanted_packages
  remove_unwanted_webapps
  install_applications
  install_voice_ai
  install_packages
  install_development_environments
  install_mise_tools
  install_vscode_extensions(repo_root)
  install_home_files(repo_root, home)
  IntelVideoWorkaround.apply(home)
  configure_voice_ai
  configure_rootless_docker(home)
  install_archon_cli(repo_root, home)
  install_user_skills(home)
  configure_codex
  configure_lazyvim(home)
  configure_bash(home)
  reload_hyprland
  remove_default_projects_directory(home)

  puts "\nSetup complete. Open a new terminal or run: source ~/.bashrc"
end

def remove_unwanted_packages
  log_step 'Removing unwanted packages'
  run 'omarchy', 'pkg', 'drop', 'aether', 'obsidian'
end

def remove_unwanted_webapps
  log_step 'Removing unwanted web apps'
  %w[Basecamp Fizzy HEY].each { |webapp| run 'omarchy', 'webapp', 'remove', webapp }
end

def install_applications
  log_step 'Installing optional applications'
  [
    ['steam', 'Steam', 'gaming', 'steam'],
    ['visual-studio-code-bin', 'VS Code', 'editor', 'vscode']
  ].each do |package, name, group, application|
    if system('pacman', '-Q', package, out: File::NULL, err: File::NULL)
      log_info "#{name} is already installed; skipping"
    else
      log_info "Installing #{name}"
      run 'omarchy', 'install', group, application
    end
  end

  battlenet_launcher = File.join(ENV.fetch('HOME'), 'Games/battlenet/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe')
  if File.file?(battlenet_launcher)
    log_info 'Battle.net is already installed; skipping'
  else
    log_info 'Installing Battle.net'
    run 'omarchy', 'install', 'gaming', 'battlenet'
  end
end

def install_voice_ai
  log_step 'Installing Voice AI'
  # The interactive installer also switches GPUs and restarts the desktop shell.
  run 'omarchy', 'pkg', 'add', 'wtype', 'voxtype-bin'

  config = File.join(ENV.fetch('HOME'), '.config/voxtype/config.toml')
  unless path_exists?(config)
    omarchy_path = ENV.fetch('OMARCHY_PATH', '/usr/share/omarchy')
    FileUtils.mkdir_p(File.dirname(config))
    FileUtils.cp(File.join(omarchy_path, 'default/voxtype/config.toml'), config)
  end
end

def configure_voice_ai
  log_step 'Configuring GPU-accelerated dictation'
  variants = JSON.parse(capture('voxtype', 'info', 'variants', '--json'))
  unless variants.fetch('variants').any? { |variant| variant['binary_name'] == 'voxtype-vulkan' && variant['installed'] }
    raise 'The Vulkan variant is missing; update voxtype-bin before running setup again'
  end

  run 'voxtype', 'setup', '--download', '--model', 'large-v3-turbo', '--no-post-install'
  unless variants['active_variant'] == 'whisper-vulkan'
    run 'sudo', 'voxtype', 'setup', 'variant', '--to', 'voxtype-vulkan'
  end

  # Keep the model resident for low latency. The service override selects NVIDIA.
  settings = {
    'engine' => 'whisper',
    'audio.max_duration_secs' => 300,
    'whisper.mode' => 'local',
    'whisper.model' => 'large-v3-turbo',
    'whisper.gpu_isolation' => false,
    'whisper.on_demand_loading' => false,
    'whisper.gpu_device' => 0
  }
  current = JSON.parse(capture('voxtype', 'config', 'get', '--json'))
  settings.each do |key, value|
    run 'voxtype', 'config', 'set', key, value.to_s unless current[key] == value
  end

  run 'systemctl', '--user', 'daemon-reload'
  run 'systemctl', '--user', 'enable', 'voxtype.service'
  run 'systemctl', '--user', 'restart', 'voxtype.service'
  log_info 'After the model loads, verify the GPU backend with: voxtype info accel'
end

def install_packages
  aur_packages = [
    # 'package-name'
  ]
  unless aur_packages.empty?
    log_step 'Installing AUR packages'
    run 'omarchy', 'pkg', 'aur', 'add', *aur_packages
  end

  repository_packages = [
    'tokei',       # Source code statistics
    'foliate',     # E-book reader
    'qbittorrent', # BitTorrent client
    'dbeaver',     # Database client
    'img2pdf',     # Convert images to PDF
    # LaTeX-to-PDF compilation, recommended fonts, and latexmk build automation
    'texlive-latexrecommended', 'texlive-fontsrecommended', 'texlive-binextra',
    # Scanner support, network scanner discovery, and graphical scanning application
    'sane', 'sane-airscan', 'simple-scan'
  ]
  log_step 'Installing repository packages'
  run 'omarchy', 'pkg', 'add', *repository_packages
end

def install_development_environments
  log_step 'Installing development environments'
  { ruby: 'rails', python: 'uv', node: 'node', bun: 'bun', zig: 'zls' }.each do |environment, command|
    if command_available?(command)
      log_info "#{environment} is already installed; skipping"
    else
      log_info "Installing #{environment}"
      run 'omarchy', 'install', 'dev-env', environment.to_s
    end
  end
end

def install_mise_tools
  log_step 'Installing mise tools'
  %w[pnpm go].each do |tool|
    if command_available?(tool)
      log_info "#{tool} is already installed; skipping"
    else
      log_info "Installing #{tool}"
      run 'mise', 'use', '--global', tool
    end
  end
end

def install_vscode_extensions(repo_root)
  log_step 'Installing VS Code extensions'
  extensions = File.readlines(File.join(repo_root, 'data/vscode-extensions.txt'), chomp: true)
                   .reject { |line| line.match?(/^\s*(#|$)/) }
  installed_extensions = capture('code', '--list-extensions').downcase.lines.map(&:chomp)
  extensions.each do |extension|
    if installed_extensions.include?(extension.downcase)
      log_info "#{extension} is already installed; skipping"
    else
      log_info "Installing #{extension}"
      run 'code', '--install-extension', extension
      installed_extensions << extension.downcase
    end
  end
end

def install_home_files(repo_root, home)
  home_source = File.join(repo_root, 'data/home')

  log_step 'Removing managed home directories'
  canonical_home = capture('realpath', '-m', '--', home).chomp
  File.foreach(File.join(repo_root, 'data/home-replace-directories.txt'), chomp: true) do |relative_dir|
    next if relative_dir.empty? || relative_dir.start_with?('#')

    destination = File.join(home, relative_dir)
    canonical_destination = capture('realpath', '-m', '--', destination).chomp
    unless canonical_destination.start_with?("#{canonical_home}/")
      raise "Invalid managed home directory: #{relative_dir}"
    end

    if path_exists?(destination)
      FileUtils.rm_r(destination)
      log_info "Removed ~/#{relative_dir}"
    else
      log_info "~/#{relative_dir} does not exist; skipping"
    end
  end

  log_step 'Installing home files'
  run 'rsync', '-a', "--exclude-from=#{repo_root}/data/home-copy-ignore.txt", "#{home_source}/", "#{home}/"
end

def install_archon_cli(repo_root, home)
  archon_cli_source = File.join(repo_root, 'components/archon-cli')

  log_step 'Installing Archon CLI'
  FileUtils.mkdir_p(["#{home}/.local/bin", "#{home}/.local/lib"])
  run 'rsync', '-a', "#{archon_cli_source}/bin/", "#{home}/.local/bin/"
  run 'rsync', '-a', '--exclude=*.md', "#{archon_cli_source}/lib/", "#{home}/.local/lib/"
end

def install_user_skills(home)
  log_step 'Installing user skills from mrzli/skills'
  data_home = ENV['XDG_DATA_HOME'].to_s.empty? ? "#{home}/.local/share" : ENV['XDG_DATA_HOME']
  skills_repo = File.join(data_home, 'archon-skills')
  github_git = ['git', '-c', 'credential.helper=', '-c', 'credential.helper=!gh auth git-credential']
  FileUtils.mkdir_p([File.dirname(skills_repo), "#{home}/.agents/skills"])
  if File.directory?("#{skills_repo}/.git")
    run(*github_git, '-C', skills_repo, 'pull', '--ff-only')
  else
    run(*github_git, 'clone', '--depth', '1', 'https://github.com/mrzli/skills.git', skills_repo)
  end
  run 'rsync', '-a', "#{skills_repo}/.agents/skills/", "#{home}/.agents/skills/"
end

def configure_lazyvim(home)
  log_step 'Enabling LazyVim REST extra'
  lazyvim_file = "#{home}/.config/nvim/lazyvim.json"
  rest_extra = 'lazyvim.plugins.extras.util.rest'
  FileUtils.mkdir_p(File.dirname(lazyvim_file))
  lazyvim = File.exist?(lazyvim_file) ? JSON.parse(File.read(lazyvim_file)) : {}
  if lazyvim.fetch('extras', nil)&.include?(rest_extra)
    log_info 'LazyVim REST extra is already enabled; skipping'
  else
    lazyvim['extras'] = (lazyvim['extras'] || []) + [rest_extra]
    File.write(lazyvim_file, "#{JSON.pretty_generate(lazyvim)}\n")
    log_info 'Enabled LazyVim REST extra'
  end
end

def configure_bash(home)
  bashrc_file = "#{home}/.bashrc"
  source_line = 'source "${XDG_CONFIG_HOME:-$HOME/.config}/archon/bashrc"'
  bashrc = File.exist?(bashrc_file) ? File.read(bashrc_file) : ''
  if bashrc.lines.map(&:chomp).include?(source_line)
    log_info 'Bash configuration is already loaded; skipping'
  else
    log_info 'Adding managed Bash configuration to ~/.bashrc'
    File.open(bashrc_file, 'a') { |file| file.write("\n#{source_line}\n") }
  end
end

def reload_hyprland
  log_step 'Reloading Hyprland configuration'
  run 'hyprctl', 'reload'
  run 'hyprctl', 'configerrors'
end

def remove_default_projects_directory(home)
  log_step 'Removing the default ~/Projects directory'
  if path_exists?("#{home}/Projects")
    FileUtils.rm_r("#{home}/Projects")
    log_info 'Removed ~/Projects'
  else
    log_info '~/Projects does not exist; skipping'
  end
end

def parse_options
  ARGV.each do |argument|
    case argument
    when '-h', '--help'
      puts usage
      return
    else
      warn "Unknown option: #{argument}\n\n#{usage}"
      exit 2
    end
  end
  true
end

def usage
  <<~TEXT
    Usage: setup.sh [OPTIONS]

    Options:
      -h, --help  Show this help and exit

    Directories listed in data/home-replace-directories.txt are always deleted and recreated.
    Other home files are preserved and data/home is copied as an overlay.
  TEXT
end
