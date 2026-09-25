require 'json'
require_relative 'helpers'

def configure_codex
  log_step 'Configuring Codex'
  settings = {
    'model' => 'gpt-6-sol',
    'model_reasoning_effort' => 'high',
    'agents.enabled' => true,
    'agents.default_subagent_model' => 'gpt-6-luna',
    'agents.default_subagent_reasoning_effort' => 'high',
    'tui.keymap.chat.edit_queued_message' => 'alt-shift-up',
    'tui.keymap.chat.prompt_stack_back' => 'alt-shift-down'
  }
  # Codex's writer preserves unrelated TOML settings and comments.
  IO.popen(['codex', 'app-server', '--stdio'], 'r+') do |server|
    requests = [
      ['initialize', { clientInfo: { name: 'archon', version: '1' } }],
      ['config/batchWrite', { edits: settings.map do |key_path, value|
        { keyPath: key_path, value: value, mergeStrategy: 'replace' }
      end }]
    ]
    requests.each_with_index do |(method, params), id|
      server.puts JSON.generate({ id: id, method: method, params: params })
      server.flush
      loop do
        line = server.gets
        raise 'Codex configuration writer exited before replying' unless line

        response = JSON.parse(line)
        next unless response['id'] == id
        raise response.fetch('error').fetch('message') if response['error']

        break
      end
      server.puts JSON.generate({ method: 'initialized' }) if id.zero?
    end
    server.close_write
  end
  log_info 'Codex uses Sol/High with Luna/High subagents and Alt+Shift+Up/Down navigation. Restart Codex to load the settings.'
end
