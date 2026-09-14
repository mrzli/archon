require_relative 'help'
require_relative 'github_inventory'
require_relative '../../shared/repository_commands'

module Archon
  module Projects
    def run_projects(arguments, home: Dir.home, root: nil)
      required_root = File.expand_path('projects/personal', home)
      Shared.run_repository_command(arguments, self, File.expand_path(root || required_root), required_root)
    rescue StandardError => error
      warn "Unexpected error: #{error.message}"
      1
    end

    def empty_message(root)
      "No local Git repositories found under #{root}/<owner>/<repository>."
    end

    def local_repositories(root)
      begin
        owners = Dir.children(root)
      rescue Errno::ENOENT
        return []
      end
      owners.select { |owner| owner != '.git' && File.lstat(File.join(root, owner)).directory? }.flat_map do |owner|
        Shared.child_repositories(File.join(root, owner)).map do |repository|
          repository.merge(owner: owner, name_with_owner: "#{owner}/#{repository[:name]}")
        end
      end.sort_by { |repository| sort_key(repository) }
    end

    def prunable_repositories(remote, root)
      names = remote.map { |repository| repository_key(repository) }.to_set
      local_repositories(root).reject { |repository| blacklisted?(repository) || names.include?(repository_key(repository)) }
    end

    def list_remote
      repositories = remote_repositories
      if repositories.empty?
        puts 'No remote repositories found after applying the blacklists.'
        return 0
      end
      width = repositories.map { |repository| repository_name(repository).length }.max
      repositories.each do |repository|
        labels = []
        labels << repository[:visibility] unless repository[:visibility] == 'public'
        labels << 'archived' if repository[:archived]
        name = repository_name(repository)
        puts(labels.empty? ? name : "#{name.ljust(width)} (#{labels.join(', ')})")
      end
      0
    rescue StandardError => error
      warn error.message
      1
    end

    def clone_repository(repository, root)
      owner_path = File.join(root, repository[:owner])
      destination = File.join(owner_path, repository[:name])
      if Shared.path_exists?(destination)
        return Shared.sync_failure(repository, "destination already exists and is not a repository: #{destination}", method(:repository_name))
      end
      begin
        FileUtils.mkdir_p(owner_path)
      rescue StandardError => error
        return Shared.sync_failure(repository, "could not create owner directory: #{error.message}", method(:repository_name))
      end
      result = Shared.run_process('git', ['clone', repository[:ssh_url], destination])
      Shared.clone_result(repository, result, method(:repository_name), program: 'Git', fallback: 'git clone failed')
    end
  end
end
