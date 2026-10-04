require_relative 'layout'

module Archon
  module Workspaces
    MISC_PROJECTS = %w[mrzli/archon mrzli/docs mrzli/js-templates mrzli/learning mrzli/mrzli.github.io mrzli/omarchy-lab mrzli/repos mrzli/skills].freeze

    def workspace_definitions(group, home: Dir.home)
      case group
      when 'general'
        [{ session: 'main', directory: File.join(home, 'projects') }]
      when 'flashcards'
        [
          { session: 'flashcards-fe', directory: File.join(home, 'projects/personal/mrzli/flashcards-fe'), dev_command: 'bun run dev' },
          { session: 'flashcards-be', directory: File.join(home, 'projects/personal/mrzli/flashcards-be'), dev_command: 'pnpm run dev' }
        ]
      when 'jslibs'
        root = File.join(home, 'projects/personal/mrzli-jslib')
        return [] unless File.directory?(root)
        find_libraries(root).map do |directory|
          { session: "jslib-#{File.basename(directory)}", directory: directory }
        end
      when 'misc'
        MISC_PROJECTS.map do |project|
          { session: "project-#{project.tr('/.', '--')}", directory: File.join(home, 'projects/personal', project) }
        end
      end
    end

    def start_editor_session(definition, backend)
      session = definition[:session]
      return 0 if backend.fetch(:has_session).call(session)
      result = backend.fetch(:create_editor_session).call(definition)
      return 0 if result[:status] == 0
      warn "Failed to start #{backend.fetch(:resource_label, 'tmux session')}: #{session}"
      warn "Failed to clean up #{backend.fetch(:resource_label, 'tmux session')}: #{session}" if result[:cleanup_status] && result[:cleanup_status] != 0
      1
    end

    def manage_editor_sessions(action, definitions, backend, exists: File.method(:exist?))
      status = 0
      definitions.each do |definition|
        session = definition[:session]
        if action == 'start'
          unless exists.call(definition[:directory])
            warn "Skipping #{session}: directory does not exist: #{definition[:directory]}"
            next
          end
          status = 1 unless start_editor_session(definition, backend) == 0
        elsif backend.fetch(:stop_session).call(session) != 0
          warn "Failed to stop #{backend.fetch(:resource_label, 'tmux session')}: #{session}"
          status = 1
        end
      end
      status
    end

    def manage_general(action, backend, home: Dir.home, exists: File.method(:exist?))
      directory = workspace_definitions('general', home: home).first.fetch(:directory)
      if action == 'start'
        unless exists.call(directory)
          warn "Skipping main: directory does not exist: #{directory}"
          return 0
        end
        return 0 if backend.fetch(:has_session).call('main')
        if backend.fetch(:create_shell_session).call(session: 'main', directory: directory) != 0
          warn "Failed to start #{backend.fetch(:resource_label, 'tmux session')}: main"
          return 1
        end
      elsif backend.fetch(:stop_session).call('main') != 0
        warn "Failed to stop #{backend.fetch(:resource_label, 'tmux session')}: main"
        return 1
      end
      0
    end

    def manage_flashcards(action, backend, home: Dir.home)
      manage_editor_sessions(action, workspace_definitions('flashcards', home: home), backend)
    end

    def manage_misc(action, backend, home: Dir.home)
      manage_editor_sessions(action, workspace_definitions('misc', home: home), backend)
    end

    def find_libraries(root)
      Dir.children(root).reject { |name| name.start_with?('.') }.map { |name| "#{File.join(root, name)}/" }
         .select { |directory| File.directory?(File.join(directory, '.git')) }.sort
    end

    def manage_jslibs(action, backend, home: Dir.home)
      root = File.join(home, 'projects/personal/mrzli-jslib')
      status = 0
      if action == 'start'
        unless File.directory?(root)
          warn "Skipping JavaScript libraries: directory does not exist: #{root}"
          return 0
        end
        workspace_definitions('jslibs', home: home).each do |definition|
          status = 1 unless start_editor_session(definition, backend) == 0
        end
      else
        result = backend.fetch(:list_sessions).call
        if result[:status] != 0
          return 0 if result[:output].include?('no server running')
          warn "Failed to list #{backend.fetch(:resource_label, 'tmux session')}s: #{result[:output]}"
          return 1
        end
        result[:output].lines(chomp: true).each do |session|
          next unless session.start_with?('jslib-')
          if backend.fetch(:kill_session).call(session) != 0
            warn "Failed to stop #{backend.fetch(:resource_label, 'tmux session')}: #{session}"
            status = 1
          end
        end
      end
      status
    end
  end
end
