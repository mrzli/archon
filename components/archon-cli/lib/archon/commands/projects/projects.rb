require_relative 'help'
require_relative 'github_inventory'
require_relative 'libs/libs'
require_relative 'secrets/secrets'
require_relative 'sync_workflow'
require_relative 'destructive_workflows'

module Archon
  module Projects
    def run_projects(arguments, home: Dir.home, root: nil)
      return Libraries.run_libraries(arguments.drop(1), home: home) if arguments.first == 'libs'
      return Secrets.run_secrets(arguments.drop(1), home: home) if arguments.first == 'secrets'
      command, *options = arguments
      return project_help(options) if %w[help --help -h].include?(command)
      unless HELP.key?(command) && command != 'global'
        warn(command ? "Unknown command: #{command}" : 'Missing command.')
        warn HELP.fetch('global')
        return 2
      end
      if options.length == 1 && %w[-h --help].include?(options.first)
        puts HELP.fetch(command)
        return 0
      end
      valid = options.empty? || (command == 'status' && options == ['--fetch']) ||
              (%w[delete prune].include?(command) && options.length == 1 && %w[-n --dry-run].include?(options.first))
      unless valid
        warn "Unexpected #{command} option: #{options.first}"
        warn HELP.fetch(command)
        return 2
      end
      required_root = File.expand_path('projects/personal', home)
      run_project_command(command, options, File.expand_path(root || required_root), required_root)
    rescue StandardError => error
      warn "Unexpected error: #{error.message}"
      1
    end

    def run_project_command(command, options, root, required_root)
      local = -> { local_repositories(root) }
      get_name = method(:repository_name)
      case command
      when 'remote'
        list_remote
      when 'status'
        repositories = local.call
        if repositories.empty?
          puts empty_message(root)
          return 0
        end
        statuses = inspect_repositories(repositories, !options.empty?, get_name)
        print_statuses(statuses)
        statuses.any? { |status| status[:error] || !status[:warnings].empty? } ? 1 : 0
      when 'sync'
        FileUtils.mkdir_p(root)
        sync_repositories(remote: method(:remote_repositories), local: local, key: method(:repository_key),
          get_name: get_name, clone: ->(repository) { clone_repository(repository, root) })
      when 'delete', 'prune'
        destructive_workflow(command, dry_run: !options.empty?, root: root, required_root: required_root,
          local: local, remote: ->(refresh) { remote_repositories(command == 'prune' && !refresh) },
          prunable: ->(remote) { prunable_repositories(remote, root) }, key: method(:repository_key),
          get_name: get_name, empty_message: empty_message(root))
      end
    end

    def project_help(options)
      if options.empty?
        puts HELP.fetch('global')
      elsif options.length == 1 && %w[-h --help].include?(options.first)
        puts HELP.fetch('help')
      elsif options.length == 1 && HELP.key?(options.first) && options.first != 'global'
        puts HELP.fetch(options.first)
      else
        warn(options.length > 1 ? "Unexpected help argument: #{options[1]}" : "Unknown command: #{options.first}")
        warn HELP.fetch('help')
        return 2
      end
      0
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
        child_repositories(File.join(root, owner)).map do |repository|
          repository.merge(owner: owner, name_with_owner: "#{owner}/#{repository[:name]}")
        end
      end.sort_by { |repository| repository_key(repository) }
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
        return sync_failure(repository, "destination already exists and is not a repository: #{destination}", method(:repository_name))
      end
      begin
        FileUtils.mkdir_p(owner_path)
      rescue StandardError => error
        return sync_failure(repository, "could not create owner directory: #{error.message}", method(:repository_name))
      end
      result = Shared.run_process('git', ['clone', repository[:ssh_url], destination])
      clone_result(repository, result, method(:repository_name), program: 'Git', fallback: 'git clone failed')
    end
  end
end
