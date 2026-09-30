require_relative 'test_helpers'

def github_ssh_runner(calls, failure: {})
  lambda do |command, arguments, **options|
    calls << [command, arguments, options]
    next failure.fetch(command) if failure.key?(command)
    if command == 'ssh-keygen'
      key = arguments.fetch(arguments.index('-f') + 1)
      File.write(key, 'fixture private key', mode: 'w', perm: 0o600)
      File.write("#{key}.pub", "ssh-ed25519 fixture-public-key fixture@example.com\n")
    end
    { status: 0, stdout: '', stderr: '' }
  end
end

test('GitHub SSH validates arguments and shows help without external or filesystem operations') do
  fixture do |fixture|
    run = ->(*_, **_) { raise 'unexpected external operation' }
    [%w[github], %w[github ssh], %w[github ssh unknown], %w[github ssh create extra],
     %w[github ssh test --invalid]].each do |arguments|
      status, = capture { Archon::Admin.run_admin(arguments, home: fixture[:home], run: run) }
      equal 2, status
    end
    [%w[help github], %w[github --help], %w[github ssh --help],
     %w[github ssh create -h], %w[github ssh test --help]].each do |arguments|
      status, output, error = capture { Archon::Admin.run_admin(arguments, home: fixture[:home], run: run) }
      equal 0, status
      assert output.include?('github ssh <create|test>')
      equal '', error
    end
    assert !File.exist?(File.join(fixture[:home], '.ssh'))
  end
end

test('GitHub SSH creation generates once, preserves unrelated config, and copies only the public key') do
  fixture do |fixture|
    directory = File.join(fixture[:home], '.ssh')
    config_path = File.join(directory, 'config')
    key = File.join(directory, 'id_ed25519_github')
    FileUtils.mkdir_p(directory)
    original_config = "Host example.net\n  User someone\n# Keep this comment"
    File.write(config_path, original_config)
    calls = []
    run = github_ssh_runner(calls)
    2.times do
      status, output, error = capture { Archon::Admin.run_admin(%w[github ssh create], home: fixture[:home], run: run) }
      equal 0, status
      assert output.include?('Public key copied to clipboard')
      equal '', error
    end
    equal [['ssh-keygen', ['-t', 'ed25519', '-C', 'goran.mrzljak@gmail.com', '-f', key, '-N', ''], { stdio: :inherit }]],
          calls.select { |command, _, _| command == 'ssh-keygen' }
    equal [['ssh-add', [key], { stdio: :inherit }]] * 2, calls.select { |command, _, _| command == 'ssh-add' }
    equal [['wl-copy', [File.read("#{key}.pub")], { stdio: :inherit }]] * 2,
          calls.select { |command, _, _| command == 'wl-copy' }
    equal 'fixture private key', File.read(key)
    config = File.read(config_path)
    assert config.start_with?(original_config + "\n")
    equal 1, config.scan(/^Host github\.com$/).length
    assert config.include?('IdentityFile ~/.ssh/id_ed25519_github')
    equal 0o600, File.stat(config_path).mode & 0o777
  end
end

test('GitHub SSH creation reuses the key and configuration written by the former script') do
  fixture do |fixture|
    directory = File.join(fixture[:home], '.ssh')
    FileUtils.mkdir_p(directory)
    key = File.join(directory, 'id_ed25519_github')
    File.write(key, 'existing key')
    File.write("#{key}.pub", 'existing public key')
    config = "Host github.com\n  HostName github.com\n  User git\n  IdentityFile #{key}\n  IdentitiesOnly yes\n  AddKeysToAgent yes\n"
    File.write(File.join(directory, 'config'), config)
    calls = []
    equal 0, Archon::Admin.run_admin(%w[github ssh create], home: fixture[:home], run: github_ssh_runner(calls))
    equal %w[ssh-add wl-copy], calls.map(&:first)
    equal 'existing key', File.read(key)
    equal config, File.read(File.join(directory, 'config'))
  end
end

test('GitHub SSH creation refuses conflicting config or an incomplete key pair without overwriting files') do
  %w[config private public].each do |kind|
    fixture do |fixture|
      directory = File.join(fixture[:home], '.ssh')
      FileUtils.mkdir_p(directory)
      target = File.join(directory, kind == 'config' ? 'config' : "id_ed25519_github#{kind == 'public' ? '.pub' : ''}")
      content = kind == 'config' ? "Host github.com\n  IdentityFile ~/.ssh/another-key\n" : 'preserve this key'
      File.write(target, content)
      calls = []
      status, output, error = capture do
        Archon::Admin.run_admin(%w[github ssh create], home: fixture[:home], run: github_ssh_runner(calls))
      end
      equal 1, status
      equal '', output
      assert error.include?('GitHub SSH operation failed:')
      equal [], calls
      equal content, File.read(target)
      equal [File.basename(target)], Dir.children(directory)
    end
  end
end

test('GitHub SSH creation stops on keygen, agent, and clipboard failures and can retry safely') do
  %w[ssh-keygen ssh-add wl-copy].each do |command|
    fixture do |fixture|
      calls = []
      status, output, error = capture do
        Archon::Admin.run_admin(%w[github ssh create], home: fixture[:home],
          run: github_ssh_runner(calls, failure: { command => { status: 5 } }))
      end
      equal 1, status
      assert !output.include?('Public key copied')
      assert error.include?("#{command} exited with status 5")
      equal command, calls.last.first
      retry_calls = []
      equal 0, Archon::Admin.run_admin(%w[github ssh create], home: fixture[:home], run: github_ssh_runner(retry_calls))
      equal command == 'ssh-keygen' ? 1 : 0, retry_calls.count { |name, _, _| name == 'ssh-keygen' }
    end
  end
end

test('GitHub SSH authentication recognizes GitHub success and rejects failures and signals') do
  greeting = "Hi fixture-user! You've successfully authenticated, but GitHub does not provide shell access.\n"
  [{ status: 1, stdout: '', stderr: greeting }, { status: 0, stdout: greeting, stderr: '' }].each do |result|
    calls = []
    run = ->(command, arguments) { calls << [command, arguments]; result }
    status, output, error = capture { Archon::Admin.run_admin(%w[github ssh test], run: run) }
    equal 0, status
    equal [['ssh', ['-T', 'git@github.com']]], calls
    equal greeting, output + error
  end
  [{ status: 255, stdout: '', stderr: 'Permission denied (publickey).' },
   { status: 1, stdout: '', stderr: 'Connection refused.' },
   { status: 255, stdout: '', stderr: greeting },
   { status: 0, stdout: '', stderr: '' }, { signal: 'SIGTERM' },
   { error: Errno::ENOENT.new('ssh') }].each do |result|
    status, _, error = capture { Archon::Admin.run_admin(%w[github ssh test], run: ->(*) { result }) }
    equal 1, status
    assert error.include?('GitHub SSH operation failed:')
  end
end

test('GitHub SSH CLI aliases use the fixture home and normalize the SSH test exit status') do
  fixture do |fixture|
    write_executable(File.join(fixture[:bin], 'ssh-keygen'), <<~'RUBY')
      #!/usr/bin/env ruby
      key = ARGV.fetch(ARGV.index('-f') + 1)
      File.write(key, 'fixture private key', mode: 'w', perm: 0o600)
      File.write("#{key}.pub", "ssh-ed25519 fixture-public-key\n")
    RUBY
    write_executable(File.join(fixture[:bin], 'ssh-add'), "#!/bin/sh\nexit 0\n")
    write_executable(File.join(fixture[:bin], 'wl-copy'), "#!/bin/sh\nprintf '%s' \"$1\" > \"$HOME/copied-key\"\n")
    write_executable(File.join(fixture[:bin], 'ssh'), <<~'SH')
      #!/bin/sh
      [ "$*" = '-T git@github.com' ] || exit 99
      echo "Hi fixture-user! You've successfully authenticated, but GitHub does not provide shell access." >&2
      exit 1
    SH
    %w[admin a].each do |command|
      equal 0, run_archon([command, 'github', 'ssh', 'create'])[:status]
      equal 0, run_archon([command, 'github', 'ssh', 'test'])[:status]
    end
    equal "ssh-ed25519 fixture-public-key\n", File.read(File.join(fixture[:home], 'copied-key'))
    assert File.file?(File.join(fixture[:home], '.ssh/id_ed25519_github'))
  end
end
