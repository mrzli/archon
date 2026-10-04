require_relative '../../shared/process'

module Archon
  module Codex
    module Terminals
      extend self

      def run_process(command, arguments)
        Open3.popen2e([command, command], *arguments) do |input, output, child|
          input.close
          begin
            text = output.read
          rescue Interrupt
            begin
              Process.kill('TERM', child.pid)
            rescue Errno::ESRCH
              nil
            end
            raise
          end
          status = child.value
          { stdout: text, stderr: '', status: status.exitstatus }
        end
      rescue SystemCallError => error
        { stdout: '', stderr: '', status: nil, error: error }
      end

      def output(run, command, arguments)
        command_output(command, run.call(command, arguments))
      end

      def command_output(command, result)
        raise "#{command}: #{result[:error].message}" if result[:error]
        unless result[:status] == 0
          detail = Shared.single_line([result[:stderr], result[:stdout]].join(' '))
          raise "#{command} failed: #{detail} (#{result[:status] || result[:signal]})"
        end
        result[:stdout]
      end

      def herdr(run, session, *arguments)
        text = output(run, 'herdr', ['--session', session, *arguments])
        JSON.parse(text).fetch('result')
      end

      def discover(run:, env: ENV)
        panes, errors = [], []
        sessions = run.call('herdr', %w[session list --json])
        unless sessions[:error].is_a?(Errno::ENOENT)
          begin
            raise "herdr session list failed: #{sessions[:stderr]}" unless sessions[:status] == 0
            JSON.parse(sessions[:stdout]).fetch('sessions').each do |session|
              next unless session.fetch('running')
              name = session.fetch('name')
              begin
                herdr(run, name, 'agent', 'list').fetch('agents').each do |agent|
                  next unless agent['agent'] == 'codex'
                  panes << { backend: :herdr, server: name, id: agent.fetch('pane_id') }
                end
              rescue StandardError => error
                errors << "Herdr #{name}: #{error.message}"
              end
            end
          rescue StandardError => error
            errors << error.message
          end
        end
        sockets = Dir.glob(File.join(env.fetch('TMUX_TMPDIR', '/tmp'), "tmux-#{Process.uid}", '*'))
                     .select { |path| File.socket?(path) }
        sockets << env['TMUX'].split(',').first unless env.fetch('TMUX', '').empty?
        sockets.uniq.each do |socket|
          begin
            result = run.call('tmux', ['-S', socket, 'list-panes', '-a', '-F', '#{pane_id}'])
            detail = [result[:stderr], result[:stdout]].join.strip
            absent = ["no server running on #{socket}", "error connecting to #{socket} (No such file or directory)", 'no sessions']
            next if result[:status] == 1 && !result[:error] && absent.include?(detail)
            text = command_output('tmux', result)
            text.each_line do |line|
              pane = { backend: :tmux, server: socket, id: line.strip }
              panes << pane if process_info(pane, run: run)&.key?(:argv)
            end
          rescue StandardError => error
            errors << "tmux #{socket}: #{error.message}"
          end
        end
        [panes, errors]
      end

      def process_info(pane, run:)
        if pane[:backend] == :herdr
          info = herdr(run, pane[:server], 'pane', 'process-info', '--pane', pane[:id]).fetch('process_info')
          processes = info.fetch('foreground_processes')
          codex = processes.find { |process| File.basename(process.fetch('argv').first.to_s) == 'codex' }
          return codex.transform_keys(&:to_sym).merge(no_shell: codex['pid'] == info['shell_pid']) if codex
          return { shell: true } if info['foreground_process_group_id'] == info['shell_pid']
          return nil
        end
        shell_pid = output(run, 'tmux', ['-S', pane[:server], 'display-message', '-p', '-t', pane[:id], '#{pane_pid}']).strip
        # /proc/stat fields after the parenthesized command: state, ppid, pgrp, session, tty, tpgid.
        foreground_pid = File.read("/proc/#{Integer(shell_pid)}/stat").split(') ', 2).last.split[5].to_i
        return nil unless foreground_pid.positive?
        argv = File.binread("/proc/#{foreground_pid}/cmdline").split("\0")
        if foreground_pid == shell_pid.to_i && File.basename(argv.first.to_s) != 'codex'
          return { shell: true }
        end
        return nil unless File.basename(argv.first.to_s) == 'codex'
        { pid: foreground_pid, argv: argv, cwd: File.readlink("/proc/#{foreground_pid}/cwd"),
          no_shell: foreground_pid == shell_pid.to_i }
      end

      def submit(pane, text, run:)
        if pane[:backend] == :herdr
          output(run, 'herdr', ['--session', pane[:server], 'pane', 'run', pane[:id], text])
        else
          output(run, 'tmux', ['-S', pane[:server], 'send-keys', '-t', pane[:id], '-l', '--', text])
          output(run, 'tmux', ['-S', pane[:server], 'send-keys', '-t', pane[:id], 'Enter'])
        end
      end

      def running?(info)
        pid = Integer(info.fetch(:pid))
        raise 'Invalid Codex process ID.' unless pid > 1
        File.binread("/proc/#{pid}/cmdline").split("\0") == info.fetch(:argv)
      rescue Errno::ENOENT, Errno::ESRCH
        false
      end

      def terminate(info, signal)
        Process.kill(signal, Integer(info.fetch(:pid))) if running?(info)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
