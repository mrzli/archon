def log_step(message)
  puts "\n==> #{message}"
end

def log_info(message)
  puts "    #{message}"
end

def run(*command, env: {})
  system(env, *command, exception: true)
end

def capture(*command)
  output = IO.popen(command, &:read)
  raise "#{command.join(' ')} failed (#{$?.exitstatus})" unless $?.success?

  output
end

def command_available?(command)
  ENV.fetch('PATH').split(File::PATH_SEPARATOR).any? do |directory|
    path = File.join(directory, command)
    File.file?(path) && File.executable?(path)
  end
end

def path_exists?(path)
  File.exist?(path) || File.symlink?(path)
end
