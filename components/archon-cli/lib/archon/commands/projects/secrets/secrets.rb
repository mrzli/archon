require_relative 'help'
require_relative '../git'

module Archon
  module Secrets
    extend self
    # Names a store may define and a template may reference. Add names here as projects need them.
    NAMES = %w[GITHUB_TOKEN EODHD_API_TOKEN APCA_API_KEY_ID APCA_API_SECRET_KEY].freeze
    # Matches .env.template and variants such as .env.local.template; each renders to its name without .template.
    TEMPLATE = /\A\.env(\.[^.]+)*\.template\z/
    PLACEHOLDER = /\$\{([A-Za-z_][A-Za-z0-9_]*)\}/

    def run_secrets(arguments, home: Dir.home, data_home: ENV['XDG_DATA_HOME'])
      command, *options = arguments
      return secrets_help(options) if %w[help --help -h].include?(command)
      unless %w[init sync].include?(command)
        warn(command ? "Unknown secrets command: #{command}" : 'Missing secrets command.')
        warn HELP.fetch('global')
        return 2
      end
      if options.length == 1 && %w[-h --help].include?(options.first)
        puts HELP.fetch(command)
        return 0
      end
      unless options.empty?
        warn "Unexpected #{command} option: #{options.first}"
        warn HELP.fetch(command)
        return 2
      end
      store = store_path(home, data_home)
      command == 'init' ? init_store(store) : sync_templates(store, File.expand_path('projects/personal', home))
    rescue StandardError => error
      warn "Unexpected error: #{error.message}"
      1
    end

    def secrets_help(options)
      if options.empty?
        puts HELP.fetch('global')
      elsif options.length == 1 && %w[init sync].include?(options.first)
        puts HELP.fetch(options.first)
      elsif options.length == 1 && %w[help -h --help].include?(options.first)
        puts HELP.fetch('help')
      else
        warn(options.length > 1 ? "Unexpected help argument: #{options[1]}" : "Unknown secrets command: #{options.first}")
        warn HELP.fetch('help')
        return 2
      end
      0
    end

    def store_path(home, data_home)
      base = data_home.to_s.empty? ? File.join(home, '.local/share') : data_home
      File.join(base, 'archon', 'secrets', 'secrets.env')
    end

    def init_store(store)
      unless Shared.path_exists?(store)
        FileUtils.mkdir_p(File.dirname(File.dirname(store)))
        Dir.mkdir(File.dirname(store), 0o700) unless File.directory?(File.dirname(store))
        File.write(store, entry_lines(NAMES), perm: 0o600)
        puts "Created #{store}"
        puts 'Fill in the secret values.'
        return 0
      end
      content = File.read(store)
      missing = NAMES - parse_store(content, store).keys
      if missing.empty?
        puts "#{store} already exists and defines every secret name. Nothing to do."
      else
        separator = content.empty? || content.end_with?("\n") ? '' : "\n"
        File.write(store, separator + entry_lines(missing), mode: 'a')
        puts "Added #{missing.join(', ')} to #{store}"
      end
      0
    end

    def entry_lines(names)
      names.map { |name| "#{name}=\n" }.join
    end

    def parse_store(content, store)
      entries = {}
      content.each_line.with_index(1) do |line, number|
        line = line.chomp
        next if line.strip.empty? || line.start_with?('#')
        name, separator, value = line.partition('=')
        raise "#{store} line #{number} is not a NAME=value entry" if separator.empty?
        entries[name] = value
      end
      entries
    end

    def sync_templates(store, root)
      unless Shared.path_exists?(store)
        warn "#{store} does not exist. Run `archon projects secrets init` first."
        return 1
      end
      unless (File.stat(store).mode & 0o077).zero?
        warn "#{store} must not be accessible by group or others. Run `chmod 600 #{store}`."
        return 1
      end
      entries = parse_store(File.read(store), store)
      (entries.keys - NAMES).each { |name| warn "Ignoring unknown secret name in #{store}: #{name}" }
      templates = Projects.local_repositories(root).flat_map do |repository|
        Dir.children(repository[:path]).grep(TEMPLATE).sort_by { |name| target_name(name) }
           .select { |name| File.file?(File.join(repository[:path], name)) }
           .map { |name| [repository, name] }
      end
      if templates.empty?
        puts "No .env*.template files found under #{root}/<owner>/<repository>."
        return 0
      end
      results = templates.map { |repository, name| [repository, name, sync_template(repository, name, entries)] }
      results.each do |repository, name, result|
        reason = result[:reason] ? "  (#{result[:reason]})" : ''
        puts "#{result[:status].ljust(10)} #{repository[:name_with_owner]}/#{target_name(name)}#{reason}"
      end
      results.all? { |*, result| %w[created updated unchanged].include?(result[:status]) } ? 0 : 1
    end

    def target_name(template_name)
      template_name.delete_suffix('.template')
    end

    def sync_template(repository, template_name, entries)
      template = File.read(File.join(repository[:path], template_name))
      target_name = target_name(template_name)
      names = template.scan(PLACEHOLDER).flatten.uniq
      unknown = names - NAMES
      return { status: 'skipped', reason: "unknown name: #{unknown.join(', ')}" } unless unknown.empty?
      empty = names.select { |name| entries[name].to_s.empty? }
      return { status: 'skipped', reason: "empty value: #{empty.join(', ')}" } unless empty.empty?
      return { status: 'skipped', reason: "#{target_name} is not ignored by Git" } unless ignored?(repository, target_name)
      header = "# Generated by `archon projects secrets sync`. Edit #{template_name} instead.\n"
      content = header + template.gsub(PLACEHOLDER) { entries.fetch(Regexp.last_match(1)) }
      target = File.join(repository[:path], target_name)
      existing = File.file?(target) ? File.read(target) : nil
      return { status: 'unchanged' } if existing == content
      write_private_file(target, content)
      { status: existing ? 'updated' : 'created' }
    rescue StandardError => error
      { status: 'failed', reason: Shared.single_line(error.message) }
    end

    def ignored?(repository, name)
      result = Projects.run_git(repository, ['check-ignore', '-q', name])
      return true if result[:status] == 0
      return false if result[:status] == 1
      detail = result[:error] ? result[:error].message : result[:signal] || result[:stderr]
      raise "could not check whether #{name} is ignored: #{Shared.single_line(detail)}"
    end

    # Writes beside the target and renames over it, so readers never see a partial file.
    def write_private_file(target, content)
      temporary = "#{target}.archon-#{Process.pid}.tmp"
      File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(content) }
      File.chmod(0o600, temporary)
      File.rename(temporary, target)
    rescue StandardError
      FileUtils.rm_f(temporary)
      raise
    end
  end
end
