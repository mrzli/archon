module Archon
  module Workspaces
    ACTION_HELP = <<~TEXT.chomp.freeze
      Usage: archon workspaces <backend> <start|stop|kill> [options]

      Options:
        --ai <tool>    AI tool for start: codex or claude (default: codex)
        -h, --help     Show this help

      Start chooses projects in an interactive checklist. Selections are remembered.
      Each project has Neovim, the selected AI tool, and a shell.
    TEXT
  end
end
