require 'fileutils'
require 'json'
require_relative 'helpers'

def setup
  delete_managed_home_dirs = false
  ARGV.each do |argument|
    case argument
    when '-d', '--delete-managed-home-dirs'
      delete_managed_home_dirs = true
    when '-h', '--help'
      puts usage
      return
    else
      warn "Unknown option: #{argument}\n\n#{usage}"
      exit 2
    end
  end

  repo_root = File.expand_path('..', __dir__)
  home = ENV.fetch('HOME')
  home_source = File.join(repo_root, 'data/home')
  archon_cli_source = File.join(repo_root, 'components/archon-cli')

  log_step 'Removing unwanted packages'
  run 'omarchy', 'pkg', 'drop', 'aether', 'obsidian'

  log_step 'Removing unwanted web apps'
  %w[Basecamp Fizzy HEY].each { |webapp| run 'omarchy', 'webapp', 'remove', webapp }

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

  aur_packages = [
    # 'package-name'
  ]
  unless aur_packages.empty?
    log_step 'Installing AUR packages'
    run 'omarchy', 'pkg', 'aur', 'add', *aur_packages
  end

  repository_packages = %w[
    tokei foliate qbittorrent dbeaver
    img2pdf
    sane sane-airscan simple-scan
  ]
  log_step 'Installing repository packages'
  run 'omarchy', 'pkg', 'add', *repository_packages

  log_step 'Installing development environments'
  { ruby: 'rails', python: 'uv', node: 'node', bun: 'bun', zig: 'zls' }.each do |environment, command|
    if command_available?(command)
      log_info "#{environment} is already installed; skipping"
    else
      log_info "Installing #{environment}"
      run 'omarchy', 'install', 'dev-env', environment.to_s
    end
  end

  log_step 'Installing mise tools'
  %w[pnpm go].each do |tool|
    if command_available?(tool)
      log_info "#{tool} is already installed; skipping"
    else
      log_info "Installing #{tool}"
      run 'mise', 'use', '--global', tool
    end
  end

  log_step 'Enabling sudoless Docker'
  run 'omarchy', 'setup', 'security', 'sudoless-docker', env: { 'OMARCHY_DEFER_REBOOT' => '1' }

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

  if delete_managed_home_dirs
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
  end

  log_step 'Installing home files'
  run 'rsync', '-a', "--exclude-from=#{repo_root}/data/home-copy-ignore.txt", "#{home_source}/", "#{home}/"

  # mise makes a newly installed Bun available without restarting the shell.
  bun = command_available?('bun') ? ['bun'] : %w[mise exec bun -- bun]
  log_step 'Installing Archon CLI build dependencies'
  run(*bun, 'install', '--frozen-lockfile', '--cwd', archon_cli_source, env: { 'NODE_ENV' => 'development' })
  log_step 'Building Archon CLI'
  run(*bun, "#{archon_cli_source}/scripts/build.ts")
  log_step 'Installing Archon CLI'
  FileUtils.mkdir_p("#{home}/.local")
  run 'rsync', '-a', "#{archon_cli_source}/dist/", "#{home}/.local/"

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

  bashrc_file = "#{home}/.bashrc"
  source_line = 'source "${XDG_CONFIG_HOME:-$HOME/.config}/archon/bashrc"'
  bashrc = File.exist?(bashrc_file) ? File.read(bashrc_file) : ''
  if bashrc.lines.map(&:chomp).include?(source_line)
    log_info 'Bash configuration is already loaded; skipping'
  else
    log_info 'Adding managed Bash configuration to ~/.bashrc'
    File.open(bashrc_file, 'a') { |file| file.write("\n#{source_line}\n") }
  end

  log_step 'Reloading Hyprland configuration'
  run 'hyprctl', 'reload'
  run 'hyprctl', 'configerrors'

  log_step 'Removing the default ~/Projects directory'
  if path_exists?("#{home}/Projects")
    FileUtils.rm_r("#{home}/Projects")
    log_info 'Removed ~/Projects'
  else
    log_info '~/Projects does not exist; skipping'
  end

  puts "\nSetup complete. Open a new terminal or run: source ~/.bashrc"
end

def usage
  <<~TEXT
    Usage: setup.sh [OPTIONS]

    Options:
      -d, --delete-managed-home-dirs  Delete and recreate directories listed in data/home-replace-directories.txt
      -h, --help                      Show this help and exit

    By default, existing home directories are preserved and data/home is copied as an overlay.
  TEXT
end
