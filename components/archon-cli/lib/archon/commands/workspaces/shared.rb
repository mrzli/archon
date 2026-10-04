require 'rbconfig'
require_relative 'help'
require 'digest'
require_relative 'layout'
require_relative 'project_selection'
require_relative '../../shared/process'

module Archon
  module Workspaces
    extend self

    def run_command(command, arguments, stdio: :inherit)
      result = Shared.run_process(command, arguments, stdio: stdio)
      warn "Could not start command: #{result[:error].message}" if result[:error]
      result[:status] || 1
    end

    def parse_arguments(arguments, help:)
      if arguments.length == 1 && %w[help -h --help].include?(arguments.first)
        puts help
        return { status: 0 }
      end
      action, *options = arguments
      unless %w[start stop].include?(action)
        warn(action ? "Unknown workspace action: #{action}" : 'Missing workspace action.')
        warn "\n#{help}"
        return { status: 2 }
      end
      parsed = { action: action, ai: DEFAULT_AI }
      seen = []
      valid = options.length.even? && options.each_slice(2).all? do |flag, value|
        key = case flag
              when '--ai' then :ai if action == 'start' && AI_COMMANDS.key?(value)
              end
        next false unless key && !seen.include?(key)
        seen << key
        parsed[key] = value
        true
      end
      unless valid
        warn "Invalid workspace options: #{options.join(' ')}"
        warn "\n#{help}"
        return { status: 2 }
      end
      parsed
    end

    def project_definitions(projects)
      projects.map do |directory|
        name = File.basename(directory).gsub(/[^a-zA-Z0-9_-]/, '-')
        { session: "archon-#{name}-#{Digest::SHA256.hexdigest(directory)[0, 12]}", directory: directory }
      end
    end

    def select_projects(backend, home:, state_home:, picker:)
      projects = WorkspaceProjects.discover_projects(home)
      if projects.empty?
        puts 'No projects found under ~/projects/cloned or ~/projects/personal.'
        return nil
      end
      state_root = state_home.to_s.empty? ? File.join(home, '.local/state') : state_home
      state_path = File.join(state_root, 'archon', "#{backend}.json")
      selection = picker.call(projects, WorkspaceProjects.load_selection(state_path), home: home)
      unless selection
        puts 'Cancelled.'
        return nil
      end
      WorkspaceProjects.save_selection(state_path, selection)
      puts 'No projects selected.' if selection.fetch('projects').empty?
      selection.fetch('projects')
    end

    def start_projects(definitions, backend)
      status = 0
      definitions.each do |definition|
        unless File.directory?(definition[:directory])
          warn "Skipping #{definition[:session]}: directory does not exist: #{definition[:directory]}"
          next
        end
        next if backend.fetch(:has_session).call(definition[:session])
        result = backend.fetch(:create_editor_session).call(definition)
        next if result[:status] == 0
        warn "Failed to start #{backend.fetch(:resource_label)}: #{definition[:session]}"
        warn "Failed to clean up #{backend.fetch(:resource_label)}: #{definition[:session]}" if result[:cleanup_status] && result[:cleanup_status] != 0
        status = 1
      end
      status
    end

    def attach_after_start(definitions, backend)
      session = definitions.find { |definition| backend.fetch(:has_session).call(definition[:session]) }
      session ? backend.fetch(:attach_session).call(session[:session]) : 0
    end

    def run_detached_stop(arguments, module_path:, entry_point:, log_name:)
      directory = File.join(ENV.fetch('XDG_STATE_HOME', File.join(Dir.home, '.local/state')), 'archon')
      FileUtils.mkdir_p(directory)
      log = File.join(directory, log_name)
      File.open(log, File::WRONLY | File::CREAT | File::APPEND, 0o600) do |output|
        puts "Stopping workspaces independently; output: #{log}"
        $stdout.flush
        # Preserve the calling server environment, but clear the routing context
        # to prevent recursive detachment.
        code = "exit #{entry_point}(ARGV, environment: {})"
        pid = Process.spawn('setsid', '--wait', RbConfig.ruby, '-r', File.expand_path(module_path), '-e', code, '--', *arguments,
                            in: File::NULL, out: output, err: output)
        _, result = Process.wait2(pid)
        status = result.exitstatus || 1
        warn "Workspace shutdown failed; see #{log}" unless status == 0
        status
      end
    rescue SystemCallError => error
      warn "Could not start workspace shutdown: #{error.message}"
      1
    end
  end
end
