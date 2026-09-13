require 'fileutils'
require 'json'
require 'tempfile'
require_relative 'helpers'

def configure_rootless_docker(home)
  log_step 'Configuring rootless Docker'
  install_rootless_docker_launcher(home)
  user = capture('id', '-un').strip
  configure_docker_subids(user)

  run 'sudo', 'loginctl', 'enable-linger', user
  run 'systemctl', '--user', 'daemon-reload'
  run 'systemctl', '--user', 'enable', 'docker.service'
  run 'systemctl', '--user', 'restart', 'docker.service'
  runtime_dir = ENV['XDG_RUNTIME_DIR'].to_s.empty? ? "/run/user/#{capture('id', '-u').strip}" : ENV['XDG_RUNTIME_DIR']
  ENV['DOCKER_HOST'] = "unix://#{runtime_dir}/docker.sock"
  security_options = JSON.parse(capture('docker', '--host', ENV['DOCKER_HOST'], 'info', '--format', '{{json .SecurityOptions}}'))
  raise 'Docker did not start in rootless mode' unless security_options.include?('name=rootless')

  run 'sudo', 'systemctl', 'disable', '--now', 'docker.service', 'docker.socket'
  if capture('id', '-nG', user).split.include?('docker')
    run 'sudo', 'gpasswd', '-d', user, 'docker'
  end
  log_info 'Rootless Docker is ready. Log out and back in so desktop apps and agents inherit its socket.'
  log_info 'Existing rootful Docker data is preserved; recreate or migrate databases separately.'
end

def install_rootless_docker_launcher(home)
  version = capture('docker', '--version')[/\ADocker version (\d+\.\d+\.\d+),/, 1]
  raise 'Could not determine the installed Docker version' unless version
  directory = "#{home}/.local/lib/archon-docker"
  launcher = "#{directory}/dockerd-rootless.sh"
  version_file = "#{directory}/version"
  if File.file?(launcher) && File.file?(version_file) && File.read(version_file).strip == version
    File.chmod(0o755, launcher)
    return
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
end

def configure_docker_subids(user)
  uid = capture('id', '-u').strip
  %w[uid gid].each do |kind|
    path = "/etc/sub#{kind}"
    run 'sudo', 'touch', path
    entries = capture('cat', path).lines.map { |line| line.strip.split(':') }
    next if entries.any? { |owner, _, count| [user, uid].include?(owner) && count.to_i >= 65_536 }

    start = [100_000, *entries.map { |_, first, count| first.to_i + count.to_i }].max
    run 'sudo', 'usermod', "--add-sub#{kind}s", "#{start}-#{start + 65_535}", user
  end
end
