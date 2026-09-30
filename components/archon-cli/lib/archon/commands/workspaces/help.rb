module Archon
  module Workspaces
    HELP = {
      'global' => <<~TEXT.chomp
        Usage: archon workspaces-tmux <start|stop> [options]
               archon workspaces-tmux kill

        Options:
          -g, --group <group>  Run only flashcards, general, jslibs, or misc-projects
              --ai <tool>      AI tool for start: codex or claude (default: codex)
          -h, --help           Show this help
      TEXT
    }.freeze
  end
end
