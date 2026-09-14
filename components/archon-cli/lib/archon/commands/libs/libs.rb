require_relative 'help'
require_relative 'build'
require_relative '../../shared/repository_commands'

module Archon
  module Libraries
    def run_libraries(arguments, home: Dir.home, root: nil)
      required_root = File.expand_path('projects/personal/mrzli-jslib', home)
      Shared.run_repository_command(arguments, self, File.expand_path(root || required_root), required_root)
    rescue StandardError => error
      warn "Unexpected error: #{error.message}"
      1
    end

    def repository_name(repository)
      repository.fetch(:name)
    end

    def repository_key(repository)
      repository_name(repository)
    end

    def sort_key(repository)
      repository_name(repository)
    end

    def empty_message(root)
      "No local Git repositories found in #{root}."
    end

    def local_repositories(root)
      Shared.child_repositories(root).sort_by { |repository| sort_key(repository) }
    rescue Errno::ENOENT
      []
    end

    def parse_repositories(output)
      repositories = JSON.parse(output)
      raise 'expected an array' unless repositories.is_a?(Array)
      repositories.map do |repository|
        unless repository.is_a?(Hash) && repository['name'].is_a?(String) && repository['nameWithOwner'].is_a?(String)
          raise 'repository name is missing'
        end
        { name: repository['name'], name_with_owner: repository['nameWithOwner'],
          private: repository['isPrivate'], archived: repository['isArchived'] }
      end
    rescue StandardError => error
      raise "Could not read GitHub CLI output: #{error.message}"
    end

    def remote_repositories(_progress = false)
      parse_repositories(Shared.github_output(%w[repo list mrzli-jslib --limit 1000 --json name,nameWithOwner,isPrivate,isArchived]))
    end

    def prunable_repositories(remote, root)
      if remote.length >= 1000
        warn 'Refusing to prune: the remote repository list may be truncated at 1000 entries.'
        return nil
      end
      names = remote.map { |repository| repository_key(repository) }.to_set
      local_repositories(root).reject { |repository| names.include?(repository_key(repository)) }
    end

    def list_remote
      repositories = remote_repositories
      width = repositories.map { |repository| repository[:name_with_owner].length }.max || 0
      repositories.each do |repository|
        labels = []
        labels << 'private' if repository[:private]
        labels << 'archived' if repository[:archived]
        name = repository[:name_with_owner]
        puts(labels.empty? ? name : "#{name.ljust(width)} (#{labels.join(', ')})")
      end
      0
    rescue StandardError => error
      warn error.message
      1
    end

    def clone_repository(repository, root)
      result = Shared.run_process('gh', ['repo', 'clone', repository[:name_with_owner], File.join(root, repository[:name])])
      Shared.clone_result(repository, result, method(:repository_name), program: 'GitHub CLI', fallback: 'GitHub CLI clone failed')
    end
  end
end
