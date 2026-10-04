require_relative 'herdr/workspaces'
require_relative 'tmux/workspaces'
require_relative 'visual_studio_code/visual_studio_code'

module Archon
  module Workspaces
    HELP = <<~TEXT.chomp.freeze
      Usage: archon workspaces list
             archon workspaces <backend> <start|stop|kill> [options]

      Commands:
        herdr (h)                Manage Herdr workspaces
        list                     List available projects without a backend
        tmux (t)                 Manage tmux workspace sessions
        visual-studio-code (vsc)  Open grouped VS Code projects or stop VS Code

      Choose a backend explicitly for start, stop, or kill. There is no default.
      Use archon workspaces list --help for listing options.
      Use archon workspaces <backend> --help for backend options.
    TEXT

    LIST_HELP = <<~TEXT.chomp.freeze
      Usage: archon workspaces list [options]

      Lists project directories under ~/projects/cloned and ~/projects/personal/<owner>.
      No backend or running workspace session is required.
    TEXT

    def run_workspace_list(arguments, home: Dir.home)
      if arguments.length == 1 && %w[help -h --help].include?(arguments.first)
        puts LIST_HELP
        return 0
      end
      unless arguments.empty?
        warn "Invalid workspace list options: #{arguments.join(' ')}\n\n#{LIST_HELP}"
        return 2
      end
      projects = WorkspaceProjects.discover_projects(home)
      puts 'No projects found under ~/projects/cloned or ~/projects/personal.' if projects.empty?
      projects.each { |directory| puts directory.sub(/\A#{Regexp.escape(home)}\//, '~/') }
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
      backend = { 'h' => 'herdr', 't' => 'tmux', 'vsc' => 'visual-studio-code' }.fetch(backend, backend)
      case backend
      when 'herdr' then return WorkspacesHerdr.run_workspaces_herdr(options, home: home)
      when 'list' then return run_workspace_list(options, home: home)
      when 'tmux' then return WorkspacesTmux.run_workspaces_tmux(options, home: home)
      when 'visual-studio-code' then return VisualStudioCode.run_visual_studio_code(options, home: home)
      when nil then warn 'Missing workspace backend.'
      else warn "Unknown workspace backend: #{backend}"
      end
      warn "\n#{HELP}"
      2
    end
  end
end
