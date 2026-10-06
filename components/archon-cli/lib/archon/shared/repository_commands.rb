require_relative 'sync_workflow'
require_relative 'destructive_workflows'

module Archon
  module Shared
    def run_repository_command(arguments, domain, root, required_root)
      command, *options = arguments
      help = domain::HELP
      if %w[help --help -h].include?(command)
        return repository_help(options, help)
      end
      unless help.key?(command) && command != 'global'
        warn(command ? "Unknown command: #{command}" : 'Missing command.')
        warn help.fetch('global')
        return 2
      end
      if options.length == 1 && %w[-h --help].include?(options.first)
        puts help.fetch(command)
        return 0
      end
      valid = options.empty? || (command == 'status' && options == ['--fetch']) ||
              (%w[delete prune].include?(command) && options.length == 1 && %w[-n --dry-run].include?(options.first))
      unless valid
        warn "Unexpected #{command} option: #{options.first}"
        warn help.fetch(command)
        return 2
      end
      local = -> { domain.local_repositories(root) }
      get_name = domain.method(:repository_name)
      key = domain.method(:repository_key)
      case command
      when 'remote'
        domain.list_remote
      when 'status'
        repositories = local.call
        if repositories.empty?
          puts domain.empty_message(root)
          return 0
        end
        statuses = inspect_repositories(repositories, !options.empty?, get_name)
        print_statuses(statuses)
        statuses.any? { |status| status[:error] || !status[:warnings].empty? } ? 1 : 0
      when 'sync'
        FileUtils.mkdir_p(root)
        sync_repositories(remote: domain.method(:remote_repositories), local: local, key: key,
          get_name: get_name, sort_key: domain.method(:sort_key), clone: ->(repository) { domain.clone_repository(repository, root) })
      when 'delete', 'prune'
        destructive_workflow(command, dry_run: !options.empty?, root: root, required_root: required_root,
          local: local, remote: ->(refresh) { domain.remote_repositories(command == 'prune' && !refresh) },
          prunable: ->(remote) { domain.prunable_repositories(remote, root) }, key: key,
          get_name: get_name, empty_message: domain.empty_message(root))
      end
    end

    def repository_help(options, help)
      if options.empty?
        puts help.fetch('global')
      elsif options.length == 1 && %w[-h --help].include?(options.first)
        puts help.fetch('help')
      elsif options.length == 1 && help.key?(options.first) && options.first != 'global'
        puts help.fetch(options.first)
      else
        warn(options.length > 1 ? "Unexpected help argument: #{options[1]}" : "Unknown command: #{options.first}")
        warn help.fetch('help')
        return 2
      end
      0
    end
  end
end
