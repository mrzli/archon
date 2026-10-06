require_relative '../shared'

module Archon
  module WorkspacesTmux
    extend self

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

    def project_definitions(projects)
      definitions = projects.map do |directory|
        { session: File.basename(directory).tr('.:', '--'), directory: directory }
      end
      definitions.group_by { |definition| definition[:session] }.each do |name, matches|
        next if matches.length == 1
        raise "tmux session name #{name.inspect} conflicts between projects: #{matches.map { |item| item[:directory] }.join(', ')}"
      end
      definitions
    end

    def create_tmux(definitions:, run: Workspaces.method(:run_command), capture: method(:capture_command), ai: Workspaces::DEFAULT_AI)
      directories = definitions.to_h { |definition| definition.values_at(:session, :directory) }
      has_session = lambda do |session|
        next false unless run.call('tmux', ['has-session', '-t', "=#{session}"], stdio: :ignore) == 0
        marker = capture.call('tmux', ['show-options', '-qv', '-t', "=#{session}:", '@archon-managed'])
        unless marker[:status] == 0 && marker[:output].strip == '1'
          raise "Refusing to use a session not managed by Archon: #{session}"
        end
        project = capture.call('tmux', ['show-options', '-qv', '-t', "=#{session}:", '@archon-project'])
        unless project[:status] == 0 && project[:output] == directories.fetch(session)
          raise "tmux session #{session.inspect} belongs to another project; stop it or rename it before continuing."
        end
        true
      end
      {
        resource_label: 'tmux session',
        has_session: has_session,
        create_editor_session: ->(definition) { create_editor_session(run, definition, ai: ai) },
        attach_session: ->(session) { run.call('tmux', ['attach-session', '-t', "=#{session}"]) }
      }
    end

    # A server whose last session just closed reports "server exited unexpectedly" while shutting down.
    def absent_server?(output)
      output.match?(/no server running|no sessions|server exited unexpectedly|error connecting .*No such file or directory/)
    end

    def kill_server(capture)
      result = capture.call('tmux', ['kill-server'])
      return 0 if result[:status] == 0 || absent_server?(result[:output])
      warn "Failed to kill tmux server: #{result[:output]}"
      1
    end

    def stop_managed_sessions(run:, capture:)
      result = capture.call('tmux', ['list-sessions', '-F', '#{session_name}' + "\t" + '#{@archon-managed}'])
      if result[:status] != 0
        return 0 if absent_server?(result[:output])
        warn "Failed to list tmux sessions: #{result[:output]}"
        return 1
      end
      status = 0
      result[:output].lines(chomp: true).each do |line|
        session, marker = line.split("\t", 2)
        next unless marker == '1'
        next if run.call('tmux', ['kill-session', '-t', "=#{session}"]) == 0
        warn "Failed to stop tmux session: #{session}"
        status = 1
      end
      status
    end

    def create_editor_session(run, definition, ai: Workspaces::DEFAULT_AI)
      session, directory = definition.values_at(:session, :directory)
      if run.call('tmux', ['new-session', '-d', '-s', session, '-c', directory, '-n', 'nvim']) != 0
        return { status: 1 }
      end
      operations = [['set-option', '-t', "=#{session}:", '@archon-managed', '1'],
                    ['set-option', '-t', "=#{session}:", '@archon-project', directory]]
      Workspaces.editor_tabs(ai: ai).each_with_index do |tab, index|
        operations << ['new-window', '-t', "=#{session}", '-c', directory, '-n', tab[:name]] unless index.zero?
        operations << ['send-keys', '-t', "=#{session}:#{tab[:name]}", tab[:command], 'Enter'] if tab[:command]
      end
      operations << ['select-window', '-t', "=#{session}:nvim"]
      operations.each do |arguments|
        if run.call('tmux', arguments) != 0
          return { status: 1, cleanup_status: run.call('tmux', ['kill-session', '-t', "=#{session}"]) }
        end
      end
      { status: 0 }
    end
  end
end
