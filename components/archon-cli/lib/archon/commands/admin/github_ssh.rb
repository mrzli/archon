require_relative '../../shared/process'

module Archon
  module Admin
    extend self

    def run_github_ssh(action, home: Dir.home, run: Shared.method(:run_process))
      if action == 'test'
        result = run.call('ssh', ['-T', 'git@github.com'])
        raise result[:error] if result[:error]
        raise "ssh was terminated by #{result[:signal]}" if result[:signal]
        $stdout.write(result[:stdout])
        $stderr.write(result[:stderr])
        # GitHub authenticates successfully but returns 1 because it provides no shell.
        output = "#{result[:stdout]}#{result[:stderr]}"
        if [0, 1].include?(result[:status]) && output.match?(/You've successfully authenticated, but GitHub does not\s+provide shell access\./)
          return 0
        end
        raise "GitHub SSH authentication was not confirmed (ssh exit status #{result[:status]})."
      end

      directory = File.join(home, '.ssh')
      key = File.join(directory, 'id_ed25519_github')
      public_key = "#{key}.pub"
      config_path = File.join(directory, 'config')
      config = File.exist?(config_path) ? File.read(config_path) : ''
      block = <<~TEXT
        Host github.com
          HostName github.com
          User git
          IdentityFile ~/.ssh/id_ed25519_github
          IdentitiesOnly yes
          AddKeysToAgent yes
      TEXT
      configured = config.include?(block) || config.include?(block.sub('~/.ssh/id_ed25519_github', key))
      if !configured && config.lines.any? { |line| line.match?(/^\s*Host\s+/i) && line.split.drop(1).include?('github.com') }
        raise "Existing GitHub SSH configuration differs; review #{config_path} before creating the key."
      end
      if Shared.path_exists?(key) != Shared.path_exists?(public_key)
        raise "Incomplete SSH key pair at #{key}; existing files were preserved."
      end

      FileUtils.mkdir_p(directory, mode: 0o700)
      if Shared.path_exists?(key)
        puts "Reusing GitHub SSH key: #{key}"
      else
        github_ssh_command(run, 'ssh-keygen', ['-t', 'ed25519', '-C', 'goran.mrzljak@gmail.com', '-f', key, '-N', ''])
        raise 'ssh-keygen did not create a complete key pair.' unless File.file?(key) && File.file?(public_key)
        puts "Created GitHub SSH key: #{key}"
      end
      github_ssh_command(run, 'ssh-add', [key])
      unless configured
        File.open(config_path, File::WRONLY | File::CREAT | File::APPEND, 0o600) do |file|
          file.write("\n") unless config.empty? || config.end_with?("\n")
          file.write(block)
        end
      end
      File.chmod(0o600, config_path)
      github_ssh_command(run, 'wl-copy', [File.read(public_key)])
      puts 'Public key copied to clipboard. Add it at https://github.com/settings/keys.'
      0
    rescue StandardError => error
      warn "GitHub SSH operation failed: #{error.message}"
      1
    end

    def github_ssh_command(run, command, arguments)
      result = run.call(command, arguments, stdio: :inherit)
      raise result[:error] if result[:error]
      raise "#{command} was terminated by #{result[:signal]}" if result[:signal]
      raise "#{command} exited with status #{result[:status]}" unless result[:status] == 0
    end
  end
end
