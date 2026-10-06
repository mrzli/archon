require 'fileutils'
require 'json'
require 'tempfile'
require_relative 'helpers'

def configure_rootless_docker(home)
  log_step 'Configuring rootless Docker'
  missing_packages = %w[rootlesskit slirp4netns].reject do |package|
    system('pacman', '-Q', package, out: File::NULL, err: File::NULL)
  end
  run 'omarchy', 'pkg', 'add', *missing_packages unless missing_packages.empty?
  changed = install_rootless_docker_launcher(home)
  user = capture('id', '-un').strip
  changed = configure_docker_subids(user) || changed

  unless capture('loginctl', 'show-user', user, '--property=Linger', '--value').strip == 'yes'
    run 'sudo', 'loginctl', 'enable-linger', user
  end
  run 'systemctl', '--user', 'daemon-reload'
  run 'systemctl', '--user', 'enable', 'docker.service'
  start_rootless_docker(home, restart: changed)
  runtime_dir = ENV['XDG_RUNTIME_DIR'].to_s.empty? ? "/run/user/#{capture('id', '-u').strip}" : ENV['XDG_RUNTIME_DIR']
  ENV['DOCKER_HOST'] = "unix://#{runtime_dir}/docker.sock"
  security_options = JSON.parse(capture('docker', '--host', ENV['DOCKER_HOST'], 'info', '--format', '{{json .SecurityOptions}}'))
  raise 'Docker did not start in rootless mode' unless security_options.include?('name=rootless')

  rootful_enabled = system('systemctl', 'is-enabled', '--quiet', 'docker.service', 'docker.socket')
  rootful_active = system('systemctl', 'is-active', '--quiet', 'docker.service', 'docker.socket')
  moved_from_rootful = rootful_enabled || rootful_active
  run 'sudo', 'systemctl', 'disable', '--now', 'docker.service', 'docker.socket' if moved_from_rootful
  if capture('id', '-nG', user).split.include?('docker')
    run 'sudo', 'gpasswd', '-d', user, 'docker'
    moved_from_rootful = true
  end
  log_info 'Rootless Docker is ready.'
  return unless moved_from_rootful

  log_info 'Log out and back in so desktop apps and agents inherit its socket.'
  log_info 'Existing rootful Docker data is preserved; recreate or migrate databases separately.'
end

# Restarting stops running containers, so restart only when the daemon's inputs changed.
def start_rootless_docker(home, restart:)
  state = capture('systemctl', '--user', 'show', 'docker.service', '--property=ActiveState,ActiveEnterTimestamp',
                  '--timestamp=unix').lines.to_h { |line| line.chomp.split('=', 2) }
  unless state['ActiveState'] == 'active'
    run 'systemctl', '--user', 'start', 'docker.service'
    return
  end
  unit = "#{home}/.config/systemd/user/docker.service"
  started = state['ActiveEnterTimestamp'].to_s.delete_prefix('@').to_i
  if restart || (File.exist?(unit) && File.mtime(unit).to_i > started)
    run 'systemctl', '--user', 'restart', 'docker.service'
  else
    log_info 'Rootless Docker is already running its current configuration; skipping restart'
  end
end

def install_rootless_docker_launcher(home)
  version = capture('docker', '--version')[/\ADocker version (\d+\.\d+\.\d+),/, 1]
  raise 'Could not determine the installed Docker version' unless version
  directory = "#{home}/.local/lib/archon-docker"
  launcher = "#{directory}/dockerd-rootless.sh"
  version_file = "#{directory}/version"
  if File.file?(launcher) && File.file?(version_file) && File.read(version_file).strip == version
    File.chmod(0o755, launcher)
    return false
  end

  FileUtils.mkdir_p(directory)
  Tempfile.create('dockerd-rootless', directory) do |file|
    run 'curl', '--fail', '--silent', '--show-error', '--location',
        "https://raw.githubusercontent.com/moby/moby/docker-v#{version}/contrib/dockerd-rootless.sh", '--output', file.path
    raise 'Downloaded Docker launcher is empty' if File.zero?(file.path)
    run '/bin/sh', '-n', file.path

    File.chmod(0o755, file.path)
    File.rename(file.path, launcher)
    File.write(version_file, "#{version}\n")
  end
  true
end

def configure_docker_subids(user)
  uid = capture('id', '-u').strip
  %w[uid gid].select do |kind|
    path = "/etc/sub#{kind}"
    exists = system('test', '-e', path)
    entries = exists ? capture('cat', path).lines.map { |line| line.strip.split(':') } : []
    next if entries.any? { |owner, _, count| [user, uid].include?(owner) && count.to_i >= 65_536 }

    start = [100_000, *entries.map { |_, first, count| first.to_i + count.to_i }].max
    run 'sudo', 'touch', path unless exists
    run 'sudo', 'usermod', "--add-sub#{kind}s", "#{start}-#{start + 65_535}", user
    true
  end.any?
end
