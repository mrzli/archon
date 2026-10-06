module Archon
  module Workspaces
    DEFAULT_AI = 'claude'
    # Claude Code fails to --continue in a directory without a saved conversation.
    CLAUDE_COMMAND = %q(if compgen -G "$HOME/.claude/projects/$(pwd | sed 's/[^[:alnum:]]/-/g')/*.jsonl" > /dev/null; ) +
                     'then claude --continue; else claude; fi'
    AI_COMMANDS = { 'codex' => 'codex resume --last', 'claude' => CLAUDE_COMMAND }.freeze

    def editor_tabs(ai: DEFAULT_AI)
      [
        { name: 'nvim', command: 'nvim .' },
        { name: ai, command: AI_COMMANDS.fetch(ai) },
        { name: 'shell' }
      ]
    end
  end
end
