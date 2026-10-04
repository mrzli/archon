require_relative 'herdr/workspaces'
require_relative 'tmux/workspaces'

module Archon
  module Workspaces
    HELP = <<~TEXT.chomp.freeze
      Usage: archon workspaces list [-g <group>]
             archon workspaces <backend> <start|stop|kill> [options]

      Commands:
        list       List configured projects by group without a backend

      Backends:
        herdr (h)  Manage Herdr workspaces
        tmux (t)   Manage tmux workspace sessions

      Choose a backend explicitly for start, stop, or kill. There is no default.
      Use archon workspaces list --help for listing options.
      Use archon workspaces <backend> --help for backend options.
    TEXT

    LIST_HELP = <<~TEXT.chomp.freeze
      Usage: archon workspaces list [options]

      Options:
        -g, --group <group>  Show only flashcards, general, jslibs, or misc
        -h, --help           Show this help

      Lists configured project paths by group. Missing directories are marked.
      No backend or running workspace session is required.
    TEXT

    def run_workspace_list(arguments, home: Dir.home)
      if arguments.length == 1 && %w[help -h --help].include?(arguments.first)
        puts LIST_HELP
        return 0
      end
      unless arguments.empty? || (arguments.length == 2 && %w[-g --group].include?(arguments.first) && GROUPS.include?(arguments.last))
        warn "Invalid workspace list options: #{arguments.join(' ')}"
        warn "\n#{LIST_HELP}"
        return 2
      end
      groups = arguments.empty? ? GROUPS : [arguments.last]
      groups.each do |group|
        puts "#{group}:"
        definitions = workspace_definitions(group, home: home)
        puts '  (no projects found)' if definitions.empty?
        definitions.each do |definition|
          directory = definition.fetch(:directory).delete_suffix('/')
          path = directory.sub(/\A#{Regexp.escape(home)}\//, '~/')
          puts "  #{path}#{File.directory?(directory) ? '' : ' (missing)'}"
        end
      end
      0
    rescue SystemCallError => error
      warn "Could not list workspace projects: #{error.message}"
      1
    end

    def run_workspaces(arguments, home: Dir.home)
      if arguments.length == 1 && %w[help -h --help].include?(arguments.first)
        puts HELP
        return 0
      end
      backend, *options = arguments
      return run_workspace_list(options, home: home) if backend == 'list'
      backend = { 'h' => 'herdr', 't' => 'tmux' }.fetch(backend, backend)
      case backend
      when 'herdr' then return WorkspacesHerdr.run_workspaces_herdr(options, home: home)
      when 'tmux' then return WorkspacesTmux.run_workspaces_tmux(options, home: home)
      when nil then warn 'Missing workspace backend.'
      else warn "Unknown workspace backend: #{backend}"
      end
      warn "\n#{HELP}"
      2
    end
  end
end
