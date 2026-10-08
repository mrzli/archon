require_relative 'layout'

module Archon
  module Workspaces
    ACTION_HELP = <<~TEXT.chomp.freeze
      Usage: archon workspaces <backend> <start|stop|restart|kill> [options]

      Options:
        --ai <tool>    AI tool for start and restart: #{AI_COMMANDS.keys.join(' or ')} (default: #{DEFAULT_AI})
        -h, --help     Show this help

      Start chooses projects in an interactive checklist. Selections are remembered.
      Restart stops, then starts the remembered selection without the checklist.
      Each project has Neovim, the selected AI tool, and a shell.
    TEXT
  end
end
