require_relative '../../shared/process'
require_relative 'layout'

module Archon
  module Workspaces
    extend self

    def run_command(command, arguments, stdio: :inherit)
      result = Shared.run_process(command, arguments, stdio: stdio)
      warn "Could not start command: #{result[:error].message}" if result[:error]
      result[:status] || 1
    end

    def capture_command(command, arguments)
      result = Shared.run_process(command, arguments)
      output = if result[:error]
                 result[:error].message
               elsif result[:signal]
                 ''
               else
                 "#{result[:stdout]}#{result[:stderr]}".rstrip
               end
      { status: result[:status] || 1, output: output }
    end

    def create_tmux(run: method(:run_command), capture: method(:capture_command))
      has_session = ->(session) { run.call('tmux', ['has-session', '-t', session], stdio: :ignore) == 0 }
      {
        has_session: has_session,
        create_editor_session: ->(definition) { create_editor_session(run, definition) },
        create_shell_session: ->(definition) { run.call('tmux', ['new-session', '-d', '-s', definition[:session], '-c', definition[:directory], '-n', 'shell']) },
        stop_session: ->(session) { has_session.call(session) ? run.call('tmux', ['kill-session', '-t', session]) : 0 },
        kill_session: ->(session) { run.call('tmux', ['kill-session', '-t', session]) },
        list_sessions: -> { capture.call('tmux', ['list-sessions', '-F', '#S']) },
        attach_session: ->(session) { run.call('tmux', ['attach-session', '-t', "=#{session}"]) }
      }
    end

    def create_editor_session(run, definition)
      session, directory = definition.values_at(:session, :directory)
      if run.call('tmux', ['new-session', '-d', '-s', session, '-c', directory, '-n', 'nvim']) != 0
        return { status: 1 }
      end
      operations = []
      editor_tabs(definition).each_with_index do |tab, index|
        operations << ['new-window', '-t', session, '-c', directory, '-n', tab[:name]] unless index.zero?
        operations << ['send-keys', '-t', "#{session}:#{tab[:name]}", tab[:command], 'Enter'] if tab[:command]
      end
      operations << ['select-window', '-t', "#{session}:nvim"]
      operations.each do |arguments|
        if run.call('tmux', arguments) != 0
          return { status: 1, cleanup_status: run.call('tmux', ['kill-session', '-t', session]) }
        end
      end
      { status: 0 }
    end
  end
end
