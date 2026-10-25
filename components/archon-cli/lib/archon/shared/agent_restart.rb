require 'shellwords'
require_relative 'agent_terminals'

module Archon
  module AgentRestart
    extend self
    # Agents get time to save state and restore the terminal; KILL is only a fallback.
    # The wait ends as soon as every process has exited.
    TERM_GRACE = 3

    # Restarts one agent's sessions. relaunch returns the command words that resume one agent process.
    def restart(label:, program:, relaunch:, terminals:, run:, wait:, term_grace:)
      prepare = lambda do |pane|
        info = terminals.process_info(pane, program, run: run)
        raise "No foreground #{label} process; session left running." unless info && info[:argv]
        raise "#{label} has no underlying shell to restart in; session left running." if info[:no_shell]
        command = "cd -- #{Shellwords.escape(info.fetch(:cwd))} && #{Shellwords.join(relaunch.call(info))}"
        { pane: pane, info: info, command: command }
      end
      restart_agents(label: label, program: program, prepare: prepare, terminals: terminals, run: run, wait: wait,
                     term_grace: term_grace)
    end

    # Restarts every discovered agent pane: prepare all launch commands, stop the whole
    # batch, then send each command to its pane's shell.
    def restart_agents(label:, program:, prepare:, terminals:, run:, wait:, term_grace:)
      panes, failures = terminals.discover(program, run: run)
      failures.each { |failure| warn failure }
      return 1 unless failures.empty?
      if panes.empty?
        puts "No #{label} CLI sessions running."
        return 0
      end
      # Validate the whole batch before stopping any processes.
      jobs = panes.map { |pane| prepare.call(pane) }
      puts "Restarting #{jobs.length} #{label} sessions..."
      $stdout.flush
      jobs.each do |job|
        begin
          terminals.terminate(job[:info], 'TERM')
        rescue StandardError => error
          failures << error.message
        end
      end
      wait.call
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + term_grace
      while jobs.any? { |job| terminals.running?(job[:info]) }
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        wait.call
      end
      jobs.each do |job|
        begin
          terminals.terminate(job[:info], 'KILL') if terminals.running?(job[:info])
        rescue StandardError => error
          failures << error.message
        end
      end
      # One short batch-wide grace period for shells to reclaim their terminals.
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
      while jobs.any? { |job| terminals.running?(job[:info]) }
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        wait.call
      end
      sent = 0
      jobs.each do |job|
        pane = job[:pane]
        begin
          unless terminals.process_info(pane, program, run: run)&.fetch(:shell, false)
            raise 'The pane has not returned to its shell.'
          end
          terminals.submit(pane, job[:command], run: run)
          sent += 1
        rescue StandardError => error
          failures << "#{pane[:backend]} #{pane[:server]} #{pane[:id]}: #{error.message} Recovery command: #{job[:command]}"
        end
      end
      failures.each { |failure| warn failure }
      puts "Sent restart commands to #{sent}/#{jobs.length} #{label} panes."
      failures.empty? ? 0 : 1
    rescue Interrupt
      warn "#{label} restart cancelled."
      130
    rescue StandardError => error
      warn "#{label} restart failed: #{error.message}"
      1
    end
  end
end
