require_relative '../../shared/process'

module Archon
  module Projects
    extend self

    def run_git(repository, arguments)
      Shared.run_process('git', ['-C', repository.fetch(:path), *arguments])
    end

    def git_output(repository, arguments)
      result = run_git(repository, arguments)
      raise "could not start Git: #{result[:error].message}" if result[:error]
      raise "Git was terminated by signal #{result[:signal]}" if result[:signal]
      raise_git_error(result, "git #{arguments.first} failed") unless result[:status] == 0
      result[:stdout]
    end

    def raise_git_error(result, fallback)
      raise Shared.single_line(result[:stderr].strip.empty? ? fallback : result[:stderr])
    end

    def github_output(arguments)
      result = Shared.run_process('gh', arguments)
      if result[:error].is_a?(Errno::ENOENT)
        raise 'GitHub CLI (`gh`) was not found. Install it and run `gh auth login` first.'
      end
      raise "Could not start GitHub CLI: #{result[:error].message}" if result[:error]
      raise "GitHub CLI was terminated by signal #{result[:signal]}." if result[:signal]
      unless result[:status] == 0
        raise(Shared.single_line(result[:stderr]).empty? ? "GitHub CLI exited with status #{result[:status] || 'unknown'}." : Shared.single_line(result[:stderr]))
      end
      result[:stdout]
    end

    def child_repositories(root)
      Dir.children(root).select { |name| File.lstat(File.join(root, name)).directory? }
         .select { |name| Shared.path_exists?(File.join(root, name, '.git')) }
         .map { |name| { name: name, path: File.join(root, name) } }
    end
  end
end
