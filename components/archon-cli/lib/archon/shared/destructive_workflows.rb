require_relative 'repository_inspection'

module Archon
  module Shared
    def destructive_workflow(command, dry_run:, root:, required_root:, local:, remote:, prunable:, key:, get_name:, empty_message:,
                             confirm: method(:confirm_deletion), remove: method(:remove_repositories))
      unless File.expand_path(root) == required_root
        warn "Refusing to delete: unexpected operation root: #{root}"
        warn "Expected operation root: #{required_root}"
        return 1
      end
      if command == 'prune'
        begin
          remote_repositories = remote.call(false)
        rescue StandardError => error
          warn "Could not list remote repositories: #{error.message}"
          return 1
        end
        repositories = prunable.call(remote_repositories)
        return 1 unless repositories
        empty_message = 'No obsolete local Git repositories found.'
      else
        repositories = local.call
      end
      if repositories.empty?
        puts empty_message
        return 0
      end
      if dry_run
        puts 'Dry run; the following directories would be deleted:'
        repositories.each { |repository| puts "  #{repository[:path]}" }
        return 0
      end
      statuses = inspect_repositories(repositories, false, get_name).select { |status| unclean?(status) }
      puts(command == 'prune' ? 'The following local repositories no longer exist remotely and will be permanently deleted:' : 'The following directories will be permanently deleted:')
      repositories.each { |repository| puts "  #{repository[:path]}" }
      puts
      return 1 unless confirm.call(statuses)
      if command == 'prune'
        begin
          refreshed = remote.call(true)
        rescue StandardError => error
          warn "Could not verify remote repositories: #{error.message}"
          warn 'Nothing was deleted.'
          return 1
        end
        remote_names = refreshed.map(&key).to_set
        restored = repositories.select { |repository| remote_names.include?(key.call(repository)) }
        unless restored.empty?
          warn 'Remote repository state changed during confirmation. Nothing was deleted.'
          warn "Now present remotely: #{restored.map(&get_name).join(', ')}"
          return 1
        end
      end
      remove.call(repositories)
    end

    def unclean?(status)
      status[:error] || !status[:warnings].empty? || status[:changes].values.any?(&:positive?) ||
        status[:stash_count] > 0 || !status[:ahead].empty?
    end

    def confirm_deletion(statuses, input: $stdin, output: $stdout, error: $stderr)
      unless input.tty? && output.tty?
        error.puts 'Deletion requires an interactive terminal. Nothing was deleted.'
        return false
      end
      prompts = statuses.empty? ? 1 : 2
      prompts.times do |index|
        if index == 1
          print_unclean_reasons(statuses, output)
          output.puts
        end
        output.print 'Type "delete" to continue: '
        output.flush
        unless input.gets&.chomp == 'delete'
          output.puts 'Deletion cancelled. Nothing was deleted.'
          return false
        end
        output.puts
      end
      true
    end

    def print_unclean_reasons(statuses, output)
      output.puts 'Unclean repositories:'
      statuses.each do |status|
        reasons = []
        unless status[:error]
          reasons << "working tree: #{format_changes(status[:changes])}" if status[:changes].values.any?(&:positive?)
          count = status[:stash_count]
          reasons << "#{count} #{count == 1 ? 'stash' : 'stashes'}" if count > 0
          reasons << "unpushed commits: #{status[:ahead].join(', ')}" unless status[:ahead].empty?
        end
        reasons.concat(status[:warnings].map { |warning| "warning: #{warning}" })
        reasons << "inspection error: #{single_line(status[:error])}" if status[:error]
        output.puts "  #{status[:name]}"
        reasons.each { |reason| output.puts "    - #{reason}" }
      end
    end

    def remove_repositories(repositories, remove: FileUtils.method(:remove_entry))
      failures = 0
      repositories.each do |repository|
        begin
          remove.call(repository[:path])
          puts "Deleted #{repository[:path]}"
        rescue StandardError => error
          failures += 1
          warn "Could not delete #{repository[:path]}: #{error.message}"
        end
      end
      if failures > 0
        warn "Failed to delete #{failures} of #{repositories.length} repositories."
        return 1
      end
      puts "Deleted #{repositories.length} repositories."
      0
    end
  end
end
