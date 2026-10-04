module Archon
  module Workspaces
    ACTION_HELP = <<~TEXT.chomp.freeze
      Usage: archon workspaces <backend> <start|stop> [options]
             archon workspaces <backend> kill

      Options:
        -g, --group <group>  Run only current, general, jslibs, misc, or projects
            --ai <tool>      AI tool for start: codex or claude (default: codex)
        -h, --help           Show this help
    TEXT
  end
end
