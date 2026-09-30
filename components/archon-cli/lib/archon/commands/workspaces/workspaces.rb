require_relative 'herdr/workspaces'
require_relative 'tmux/workspaces'

module Archon
  module Workspaces
    HELP = <<~TEXT.chomp.freeze
      Usage: archon workspaces <backend> <start|stop|kill> [options]

      Backends:
        herdr (h)  Manage Herdr workspaces
        tmux (t)   Manage tmux workspace sessions

      Choose a backend explicitly. There is no default.
      Use archon workspaces <backend> --help for backend options.
    TEXT

    def run_workspaces(arguments)
      if arguments.length == 1 && %w[help -h --help].include?(arguments.first)
        puts HELP
        return 0
      end
      backend, *options = arguments
      backend = { 'h' => 'herdr', 't' => 'tmux' }.fetch(backend, backend)
      case backend
      when 'herdr' then return WorkspacesHerdr.run_workspaces_herdr(options)
      when 'tmux' then return WorkspacesTmux.run_workspaces_tmux(options)
      when nil then warn 'Missing workspace backend.'
      else warn "Unknown workspace backend: #{backend}"
      end
      warn "\n#{HELP}"
      2
    end
  end
end
