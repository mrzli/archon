module Archon
  module Workspaces
    DEFAULT_AI = 'claude'
    # Claude Code fails to --continue in a directory without a saved conversation.
    CLAUDE_COMMAND = %q(if compgen -G "$HOME/.claude/projects/$(pwd | sed 's/[^[:alnum:]]/-/g')/*.jsonl" > /dev/null; ) +
                     'then claude --continue; else claude; fi'
    AI_COMMANDS = { 'claude' => CLAUDE_COMMAND, 'codex' => 'codex resume --last' }.freeze

    def project_tabs(ai:)
      [{ name: 'shell' }, { name: ai, command: AI_COMMANDS[ai] }]
    end
  end
end
