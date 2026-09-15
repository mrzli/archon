require 'json'
require_relative 'helpers'

def configure_codex_keybindings
  log_step 'Configuring Codex navigation keys'
  bindings = {
    'edit_queued_message' => 'alt-shift-up',
    'prompt_stack_back' => 'alt-shift-down'
  }
  # Codex's writer preserves unrelated TOML settings and comments.
  IO.popen(['codex', 'app-server', '--stdio'], 'r+') do |server|
    requests = [
      ['initialize', { clientInfo: { name: 'archon', version: '1' } }],
      ['config/batchWrite', { edits: bindings.map do |action, binding|
        { keyPath: "tui.keymap.chat.#{action}", value: binding, mergeStrategy: 'replace' }
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
  log_info 'Codex navigation uses Alt+Shift+Up/Down. Restart Codex to load the bindings.'
end
