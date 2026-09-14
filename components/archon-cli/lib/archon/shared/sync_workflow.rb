require_relative 'repository_inspection'

module Archon
  module Shared
    def sync_failure(repository, message, get_name)
      { name: get_name.call(repository), succeeded: false, message: "ERROR: #{single_line(message)}" }
    end

    def update_repository(repository, get_name)
      git_output(repository, %w[fetch --all --prune])
      branch = symbolic_branch(repository)
      return sync_failure(repository, 'detached HEAD', get_name) unless branch
      changes = working_tree_changes(repository)
      if changes.values.any?(&:positive?)
        return sync_failure(repository, "working tree is not clean (#{format_changes(changes)})", get_name)
      end
      upstream = branch_upstream(repository, branch)
      return sync_failure(repository, "#{branch} has no upstream", get_name) unless upstream
      previous = git_output(repository, %w[rev-parse HEAD]).strip
      git_output(repository, ['merge', '--ff-only', upstream])
      current = git_output(repository, %w[rev-parse HEAD]).strip
      { name: get_name.call(repository), succeeded: true,
        message: "[#{branch} -> #{upstream}]  #{current == previous ? 'up to date' : 'updated'}" }
    rescue StandardError => error
      sync_failure(repository, error.message, get_name)
    end

    def sync_repositories(remote:, local:, key:, get_name:, clone:, sort_key:, update: method(:update_repository))
      begin
        remote_repositories = remote.call
      rescue StandardError => error
        warn "Could not list remote repositories: #{error.message}"
        return 1
      end
      local_repositories = local.call
      names = local_repositories.map(&key).to_set
      operations = local_repositories.map { |repository| [repository, -> { update.call(repository, get_name) }] }
      operations.concat(remote_repositories.reject { |repository| names.include?(key.call(repository)) }
        .map { |repository| [repository, -> { clone.call(repository) }] })
      operations.sort_by! { |repository, _| sort_key.call(repository) }
      if operations.empty?
        puts 'No local or remote Git repositories found.'
        return 0
      end
      puts "Synchronizing #{operations.length} repositories..."
      width = operations.map { |repository, _| get_name.call(repository).length }.max
      failed = false
      operations.each_with_index do |(repository, operation), index|
        print "[#{(index + 1).to_s.rjust(operations.length.to_s.length)}/#{operations.length}] #{get_name.call(repository).ljust(width)}  "
        begin
          result = operation.call
        rescue StandardError => error
          result = sync_failure(repository, error.message, get_name)
        end
        puts result[:message]
        failed = true unless result[:succeeded]
      end
      failed ? 1 : 0
    end

    def clone_result(repository, result, get_name, program:, fallback:)
      message = if result[:error]
                  "could not start #{program}: #{result[:error].message}"
                elsif result[:signal]
                  "#{program} was terminated by signal #{result[:signal]}"
                elsif result[:status] != 0
                  single_line(result[:stderr]).empty? ? fallback : single_line(result[:stderr])
                end
      return sync_failure(repository, message, get_name) if message
      { name: get_name.call(repository), succeeded: true, message: 'cloned' }
    end
  end
end
