require_relative 'process'

module Archon
  module Shared
    def format_changes(changes)
      parts = changes.filter_map { |key, count| "#{key}: #{count}" if count > 0 }
      parts.empty? ? 'clean' : parts.join(', ')
    end

    def branch_upstream(repository, branch)
      output = git_output(repository, ['for-each-ref', '--format=%(upstream:short)', "refs/heads/#{branch}"]).strip
      output.empty? ? nil : output
    end

    def symbolic_branch(repository)
      result = run_git(repository, %w[symbolic-ref --quiet --short HEAD])
      return result[:stdout].strip if result[:status] == 0
      return nil if result[:status] == 1
      raise_git_error(result, 'could not determine current branch')
    end

    def working_tree_changes(repository)
      entries = git_output(repository, ['status', '--porcelain=v1', '-z', '--untracked-files=normal']).split("\0")
      changes = { staged: 0, unstaged: 0, untracked: 0 }
      until entries.empty?
        status = entries.shift[0, 2]
        if status == '??'
          changes[:untracked] += 1
          next
        end
        changes[:staged] += 1 unless status[0] == ' '
        changes[:unstaged] += 1 unless status[1] == ' '
        entries.shift if status.match?(/[RC]/)
      end
      changes
    end

    def ahead_branches(repository, warnings)
      output = git_output(repository, ['for-each-ref', '--format=%(refname:short)%09%(refname)%09%(upstream:short)%09%(upstream)', 'refs/heads'])
      output.lines(chomp: true).filter_map do |line|
        name, ref, upstream, upstream_ref = line.split("\t", -1)
        unless upstream.empty?
          result = run_git(repository, ['rev-list', '--count', "#{upstream_ref}..#{ref}"])
          if result[:status] == 0
            count = result[:stdout].strip.to_i
            next count > 0 ? "#{name}=#{count}" : nil
          end
          warnings << "#{name} upstream is missing"
        end
        count = git_output(repository, ['rev-list', '--count', ref, '--not', '--remotes']).strip.to_i
        "#{name}=#{count} (#{upstream.empty? ? 'no upstream' : 'upstream missing'})" if count > 0
      end
    end

    def inspect_repositories(repositories, fetch, get_name)
      repositories.map do |repository|
        warnings = []
        if fetch
          begin
            git_output(repository, %w[fetch --all --prune])
          rescue StandardError => error
            warnings << "fetch failed: #{error.message}"
          end
        end
        begin
          branch = symbolic_branch(repository) || "detached@#{git_output(repository, %w[rev-parse --short HEAD]).strip}"
          { name: get_name.call(repository), branch: branch, changes: working_tree_changes(repository),
            stash_count: git_output(repository, %w[stash list --format=%gd]).lines.length,
            ahead: ahead_branches(repository, warnings), warnings: warnings }
        rescue StandardError => error
          { name: get_name.call(repository), error: error.message, warnings: warnings }
        end
      end
    end

    def print_statuses(statuses)
      name_width = statuses.map { |status| status[:name].length }.max || 0
      valid = statuses.reject { |status| status[:error] }
      branch_width = valid.map { |status| status[:branch].length }.max || 0
      changes_width = valid.map { |status| format_changes(status[:changes]).length }.max || 0
      statuses.each do |status|
        name = status[:name].ljust(name_width)
        if status[:error]
          puts "#{name}  ERROR: #{single_line(status[:error])}"
          next
        end
        warnings = status[:warnings].empty? ? '' : "  warnings: #{status[:warnings].map { |warning| single_line(warning) }.join(', ')}"
        ahead = status[:ahead].empty? ? 'none' : status[:ahead].join(', ')
        puts "#{name}  [#{status[:branch].ljust(branch_width)}]  #{format_changes(status[:changes]).ljust(changes_width)}  stash: #{status[:stash_count]}  ahead: #{ahead}#{warnings}"
      end
    end
  end
end
