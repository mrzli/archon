module Archon
  module Workspaces
    DEFAULT_AI = 'claude'
    # Claude Code fails to --continue in a directory without a saved conversation.
    CLAUDE_COMMAND = %q(if compgen -G "$HOME/.claude/projects/$(pwd | sed 's/[^[:alnum:]]/-/g')/*.jsonl" > /dev/null; ) +
                     'then claude --continue; else claude; fi'
    AI_COMMANDS = { 'claude' => CLAUDE_COMMAND, 'codex' => 'codex resume --last' }.freeze
    # Commands that run in tabs with these names, for new and existing workspaces.
    TAB_COMMANDS = { 'nvim' => 'nvim .', 'lazygit' => 'lazygit' }.merge(AI_COMMANDS).freeze

    def editor_tabs(ai: DEFAULT_AI)
      %W[nvim lazygit #{ai} shell].map { |name| { name: name, command: TAB_COMMANDS[name] }.compact }
    end
  end
end
