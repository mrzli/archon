require 'digest'
require 'rbconfig'
require_relative 'help'
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

    # Captures a backend command's output; failures carry stderr and stdout for diagnostics.
    def capture_command(command, arguments)
      result = Shared.run_process(command, arguments)
      output = if result[:error]
                 result[:error].message
               elsif result[:signal]
                 "#{command} was terminated by signal #{result[:signal]}"
               elsif result[:status] == 0
                 result[:stdout].rstrip
               else
                 "#{result[:stderr]}#{result[:stdout]}".strip
               end
      { status: result[:status] || 1, output: output }
    end

    def parse_arguments(arguments, help:)
      if arguments.length == 1 && %w[help -h --help].include?(arguments.first)
        puts help
        return { status: 0 }
      end
      action, *options = arguments
      unless %w[start stop kill].include?(action)
        warn(action ? "Unknown workspace action: #{action}" : 'Missing workspace action.')
        warn "\n#{help}"
        return { status: 2 }
      end
      valid = options.empty? || (action == 'start' && options.length == 2 &&
                                 options.first == '--ai' && AI_COMMANDS.key?(options.last))
      unless valid
        warn "Invalid workspace options: #{options.join(' ')}"
        warn "\n#{help}"
        return { status: 2 }
      end
      { action: action, ai: options.empty? ? DEFAULT_AI : options.last }
    end

    def project_definitions(projects)
      projects.map do |directory|
        name = File.basename(directory).gsub(/[^a-zA-Z0-9_-]/, '-')
        { session: "archon-#{name}-#{Digest::SHA256.hexdigest(directory)[0, 12]}", directory: directory, label: File.basename(directory) }
      end
    end

    def select_projects(backend, home:, state_home:, picker:)
      projects = WorkspaceProjects.discover_projects(home)
      if projects.empty?
        puts 'No projects found under ~/projects/cloned or ~/projects/personal.'
        return nil
      end
      state_path = WorkspaceProjects.selection_path(backend, home: home, state_home: state_home)
      saved = WorkspaceProjects.load_selection(state_path)
      selection = picker.call(projects, saved, home: home)
      unless selection
        puts 'Cancelled.'
        return nil
      end
      WorkspaceProjects.save_selection(state_path, saved.merge(selection))
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
        if backend.fetch(:has_session).call(definition[:session])
          next unless backend[:start_existing_session]
          result = backend.fetch(:start_existing_session).call(definition)
        else
          result = backend.fetch(:create_editor_session).call(definition)
        end
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

    def run_detached_stop(arguments, module_path:, entry_point:, log:)
      FileUtils.mkdir_p(File.dirname(log))
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
