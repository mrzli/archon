module Archon
  module Workspaces
    def editor_tabs(definition)
      tabs = [
        { name: 'nvim', command: 'nvim .' },
        { name: 'codex', command: 'codex resume --last' }
      ]
      tabs << { name: 'dev', command: definition[:dev_command] } if definition[:dev_command]
      tabs << { name: 'shell' }
      tabs
    end
  end
end
