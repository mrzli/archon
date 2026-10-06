require_relative 'layout'

module Archon
  module Workspaces
    ACTION_HELP = <<~TEXT.chomp.freeze
      Usage: archon workspaces <backend> <start|stop|kill> [options]

      Options:
        --ai <tool>    AI tool for start: #{AI_COMMANDS.keys.join(' or ')} (default: #{DEFAULT_AI})
        -h, --help     Show this help

      Start chooses projects in an interactive checklist. Selections are remembered.
      Each project has Neovim, the selected AI tool, and a shell.
    TEXT
  end
end
