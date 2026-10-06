require_relative '../../shared/process'

module Archon
  module Projects
    extend self
    ORGANIZATION_BLACKLIST = %w[mrzli-courses mrzli-gh-actions mrzli-other mrzli-vscode-extensions].freeze
    REPOSITORY_BLACKLIST = [].freeze
    ORGANIZATION_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9-]*\z/
    REPOSITORY_PATTERN = %r{\A[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+\z}
    REPOSITORY_QUERY = <<~JQ.chomp.freeze
      .[]
      | [
          .id,
          .full_name,
          .ssh_url,
          .archived,
          (.visibility // (if .private then "private" else "public" end))
        ]
      | @tsv
    JQ

    def repository_name(repository)
      repository.fetch(:name_with_owner)
    end

    def repository_key(repository)
      repository_name(repository).downcase
    end

    def blacklisted?(repository, organizations = ORGANIZATION_BLACKLIST, repositories = REPOSITORY_BLACKLIST)
      organizations.any? { |owner| owner.downcase == repository[:owner].downcase } ||
        repositories.any? { |name| name.downcase == repository_key(repository) }
    end

    def blacklist_lookup_names(repositories = REPOSITORY_BLACKLIST)
      repositories.select { |name| REPOSITORY_PATTERN.match?(name) }.uniq(&:downcase)
    end

    def parse_repository(row)
      fields = row.split("\t", -1)
      id, full_name, ssh_url, archived, visibility = fields
      owner, name = full_name.to_s.split('/', 2)
      unless fields.length == 5 && !id.empty? && owner && !owner.empty? && name && !name.empty? &&
             !ssh_url.empty? && %w[true false].include?(archived) && !visibility.empty?
        raise "GitHub returned incomplete repository data: #{row}"
      end
      { id: id, owner: owner, name: name, name_with_owner: full_name, ssh_url: ssh_url,
        archived: archived == 'true', visibility: visibility }
    end

    def validate_blacklists(username, organizations, canonical = {}, organization_blacklist: ORGANIZATION_BLACKLIST,
                            repository_blacklist: REPOSITORY_BLACKLIST)
      errors = []
      owners = organizations.map(&:downcase).to_set
      excluded_owners = Set.new
      organization_blacklist.each do |organization|
        key = organization.downcase
        if !ORGANIZATION_PATTERN.match?(organization)
          errors << "Invalid organization blacklist entry \"#{organization}\"."
        elsif excluded_owners.include?(key)
          errors << "Duplicate organization blacklist entry \"#{organization}\"."
        else
          excluded_owners.add(key)
          unless owners.include?(key)
            errors << "Blacklisted organization \"#{organization}\" is not an active organization owned by \"#{username}\"."
          end
        end
      end
      excluded_repositories = Set.new
      repository_blacklist.each do |name|
        key = name.downcase
        if !REPOSITORY_PATTERN.match?(name)
          errors << "Invalid repository blacklist entry \"#{name}\"; expected \"owner/repository\"."
        elsif excluded_repositories.include?(key)
          errors << "Duplicate repository blacklist entry \"#{name}\"."
        else
          excluded_repositories.add(key)
          if !canonical.key?(key)
            errors << "Blacklisted repository \"#{name}\" does not exist or is not accessible."
          elsif canonical[key].downcase != key
            errors << "Blacklisted repository \"#{name}\" is now \"#{canonical[key]}\"."
          else
            owner = canonical[key].split('/').first.downcase
            unless owner == username.downcase || owners.include?(owner)
              errors << "Blacklisted repository \"#{name}\" is not owned by \"#{username}\" or an organization owned by that user."
            end
          end
        end
      end
      raise (['Blacklist validation failed:'] + errors.map { |error| "  - #{error}" }).join("\n") unless errors.empty?
      [excluded_owners, excluded_repositories]
    end

    def github_api(arguments)
      Shared.github_output(['api', '--hostname', 'github.com', *arguments])
    end

    def remote_repositories(progress = false)
      puts 'Discovering the authenticated GitHub user...' if progress
      username = github_api(['user', '--jq', '.login']).strip
      raise 'GitHub returned an empty username.' if username.empty?
      puts 'Discovering owned GitHub organizations...' if progress
      organizations = github_api(['--paginate', 'user/memberships/orgs?state=active&per_page=100', '--jq',
                                  '.[] | select(.role == "admin") | .organization.login'])
        .lines.map(&:strip).reject(&:empty?).sort_by(&:downcase)
      puts 'Validating repository exclusions...' if progress
      canonical = {}
      blacklist_lookup_names.each do |name|
        begin
          canonical[name.downcase] = github_api(["repos/#{name}", '--jq', '.full_name']).strip
        rescue StandardError
          # Validation reports inaccessible blacklist entries together.
        end
      end
      excluded_owners, excluded_repositories = validate_blacklists(username, organizations, canonical)
      endpoints = [[username, 'user/repos?affiliation=owner&visibility=all&per_page=100']]
      endpoints.concat(organizations.reject { |owner| excluded_owners.include?(owner.downcase) }
        .map { |owner| [owner, "orgs/#{owner}/repos?type=all&per_page=100"] })
      repositories = {}
      endpoints.each do |owner, endpoint|
        puts "Listing repositories for #{owner}..." if progress
        github_api(['--paginate', endpoint, '--jq', REPOSITORY_QUERY]).lines(chomp: true).reject(&:empty?).each do |row|
          repository = parse_repository(row)
          repositories[repository_key(repository)] = repository
        end
      end
      excluded_repositories.each { |key| repositories.delete(key) }
      repositories.values.sort_by { |repository| repository_key(repository) }
    end
  end
end
