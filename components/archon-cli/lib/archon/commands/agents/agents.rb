require_relative 'claude'
require_relative 'codex'

module Archon
  module Agents
    extend self

    HELP = <<~TEXT.chomp.freeze
      Usage: archon agents restart

      Commands:
        restart  Restart all Claude Code and Codex CLI sessions

      Restart covers agent sessions in running Herdr and tmux sessions.
      Run from a separate shell with agent sessions idle and input boxes empty.
      Claude resumes each session's conversation; Codex resumes the latest one in each directory.
      Each session continues in its existing pane. No selection or confirmation.
    TEXT

    def run_agents(arguments, restart: method(:restart))
      help = [%w[help], %w[-h], %w[--help]]
      %w[restart].each { |command| help.push(['help', command], [command, '-h'], [command, '--help']) }
      if help.include?(arguments)
        puts HELP
        return 0
      end
      case arguments
      when ['restart'] then restart.call
      else
        warn "Expected restart.\n\n#{HELP}"
        2
      end
    end

    # A failed Claude restart does not prevent the Codex restart; Ctrl+C cancels both.
    def restart(claude: Claude.method(:restart), codex: Codex.method(:restart))
      status = claude.call
      return status if status == 130
      [status, codex.call].max
    end
  end
end
