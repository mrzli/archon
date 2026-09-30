module Archon
  module Workspaces
    DEFAULT_AI = 'codex'
    AI_COMMANDS = { 'codex' => 'codex resume --last', 'claude' => 'claude --continue' }.freeze

    def editor_tabs(definition, ai: DEFAULT_AI)
      tabs = [
        { name: 'nvim', command: 'nvim .' },
        { name: ai, command: AI_COMMANDS.fetch(ai) }
      ]
      tabs << { name: 'dev', command: definition[:dev_command] } if definition[:dev_command]
      tabs << { name: 'shell' }
      tabs
    end
  end
end
