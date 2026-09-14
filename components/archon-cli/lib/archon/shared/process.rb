require 'open3'
require 'fileutils'
require 'json'
require 'set'

module Archon
  module Shared
    extend self

    def run_process(command, arguments, cwd: nil, stdio: :capture)
      options = cwd ? { chdir: cwd } : {}
      if stdio == :capture
        output, error, status = Open3.capture3([command, command], *arguments, **options)
      else
        options.merge!(in: File::NULL, out: File::NULL, err: File::NULL) if stdio == :ignore
        pid = Process.spawn([command, command], *arguments, **options)
        _, status = Process.wait2(pid)
        output = error = ''
      end
      { stdout: output, stderr: error, status: status.exitstatus,
        signal: status.signaled? ? "SIG#{Signal.signame(status.termsig)}" : nil }
    rescue SystemCallError => error
      { stdout: '', stderr: '', status: nil, error: error }
    end

    def single_line(value)
      value.to_s.gsub(/\s+/, ' ').strip
    end

    def path_exists?(path)
      File.lstat(path)
      true
    rescue Errno::ENOENT
      false
    end

    def run_git(repository, arguments)
      run_process('git', ['-C', repository.fetch(:path), *arguments])
    end

    def git_output(repository, arguments)
      result = run_git(repository, arguments)
      raise "could not start Git: #{result[:error].message}" if result[:error]
      raise "Git was terminated by signal #{result[:signal]}" if result[:signal]
      raise_git_error(result, "git #{arguments.first} failed") unless result[:status] == 0
      result[:stdout]
    end

    def raise_git_error(result, fallback)
      raise single_line(result[:stderr].strip.empty? ? fallback : result[:stderr])
    end

    def github_output(arguments)
      result = run_process('gh', arguments)
      if result[:error].is_a?(Errno::ENOENT)
        raise 'GitHub CLI (`gh`) was not found. Install it and run `gh auth login` first.'
      end
      raise "Could not start GitHub CLI: #{result[:error].message}" if result[:error]
      raise "GitHub CLI was terminated by signal #{result[:signal]}." if result[:signal]
      unless result[:status] == 0
        raise(single_line(result[:stderr]).empty? ? "GitHub CLI exited with status #{result[:status] || 'unknown'}." : single_line(result[:stderr]))
      end
      result[:stdout]
    end

    def child_repositories(root)
      Dir.children(root).select { |name| File.lstat(File.join(root, name)).directory? }
         .select { |name| path_exists?(File.join(root, name, '.git')) }
         .map { |name| { name: name, path: File.join(root, name) } }
    end
  end
end
