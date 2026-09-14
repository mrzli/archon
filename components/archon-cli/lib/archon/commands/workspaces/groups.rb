require_relative 'tmux'

module Archon
  module Workspaces
    PROJECTS = %w[mrzli/archon mrzli/docs mrzli/js-templates mrzli/learning mrzli/mrzli.github.io mrzli/repos mrzli/skills].freeze

    def start_editor_session(definition, tmux)
      session = definition[:session]
      return 0 if tmux.fetch(:has_session).call(session)
      result = tmux.fetch(:create_editor_session).call(definition)
      return 0 if result[:status] == 0
      warn "Failed to start tmux session: #{session}"
      warn "Failed to clean up tmux session: #{session}" if result[:cleanup_status] && result[:cleanup_status] != 0
      1
    end

    def manage_editor_sessions(action, definitions, tmux, exists: File.method(:exist?))
      status = 0
      definitions.each do |definition|
        session = definition[:session]
        if action == 'start'
          unless exists.call(definition[:directory])
            warn "Skipping #{session}: directory does not exist: #{definition[:directory]}"
            next
          end
          status = 1 unless start_editor_session(definition, tmux) == 0
        elsif tmux.fetch(:stop_session).call(session) != 0
          warn "Failed to stop tmux session: #{session}"
          status = 1
        end
      end
      status
    end

    def manage_general(action, tmux, home: Dir.home, exists: File.method(:exist?))
      directory = File.join(home, 'projects')
      if action == 'start'
        unless exists.call(directory)
          warn "Skipping main: directory does not exist: #{directory}"
          return 0
        end
        return 0 if tmux.fetch(:has_session).call('main')
        if tmux.fetch(:create_shell_session).call(session: 'main', directory: directory) != 0
          warn 'Failed to start tmux session: main'
          return 1
        end
      elsif tmux.fetch(:stop_session).call('main') != 0
        warn 'Failed to stop tmux session: main'
        return 1
      end
      0
    end

    def manage_flashcards(action, tmux, home: Dir.home)
      definitions = [
        { session: 'flashcards-fe', directory: File.join(home, 'projects/personal/mrzli/flashcards-fe'), dev_command: 'bun run dev' },
        { session: 'flashcards-be', directory: File.join(home, 'projects/personal/mrzli/flashcards-be'), dev_command: 'pnpm run dev' }
      ]
      manage_editor_sessions(action, definitions, tmux)
    end

    def manage_misc_projects(action, tmux, home: Dir.home)
      definitions = PROJECTS.map do |project|
        { session: "project-#{project.tr('/.', '--')}", directory: File.join(home, 'projects/personal', project) }
      end
      manage_editor_sessions(action, definitions, tmux)
    end

    def find_libraries(root)
      Dir.children(root).reject { |name| name.start_with?('.') }.map { |name| "#{File.join(root, name)}/" }
         .select { |directory| File.directory?(File.join(directory, '.git')) }.sort
    end

    def manage_jslibs(action, tmux, home: Dir.home)
      root = File.join(home, 'projects/personal/mrzli-jslib')
      status = 0
      if action == 'start'
        unless File.directory?(root)
          warn "Skipping JavaScript libraries: directory does not exist: #{root}"
          return 0
        end
        find_libraries(root).each do |directory|
          definition = { session: "jslib-#{File.basename(directory)}", directory: directory }
          status = 1 unless start_editor_session(definition, tmux) == 0
        end
      else
        result = tmux.fetch(:list_sessions).call
        if result[:status] != 0
          return 0 if result[:output].include?('no server running')
          warn "Failed to list tmux sessions: #{result[:output]}"
          return 1
        end
        result[:output].lines(chomp: true).each do |session|
          next unless session.start_with?('jslib-')
          if tmux.fetch(:kill_session).call(session) != 0
            warn "Failed to stop tmux session: #{session}"
            status = 1
          end
        end
      end
      status
    end
  end
end
