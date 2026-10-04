module Archon
  module Workspaces
    DEFAULT_AI = 'codex'
    AI_COMMANDS = { 'codex' => 'codex resume --last', 'claude' => 'claude --continue' }.freeze

    def editor_tabs(ai: DEFAULT_AI)
      [
        { name: 'nvim', command: 'nvim .' },
        { name: ai, command: AI_COMMANDS.fetch(ai) },
        { name: 'shell' }
      ]
    end
  end
end
