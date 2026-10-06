require_relative 'commands/admin/admin'
require_relative 'commands/claude/claude'
require_relative 'commands/codex/codex'
require_relative 'commands/libs/libs'
require_relative 'commands/projects/projects'
require_relative 'commands/workspaces/workspaces'

module Archon
  extend self

  GLOBAL_HELP = <<~TEXT.chomp.freeze
    Usage: archon <command> [options]

    Commands:
      admin (a)                 Manage workstation services
      claude                    Restart Claude Code sessions
      codex                     Restart Codex CLI sessions
      help (h)                  Show this help
      libs (l)                  Manage local JavaScript libraries
      projects (p)              Manage personal project repositories
      workspaces (w)            Manage Herdr, tmux, or VS Code workspaces
  TEXT

  def main(arguments)
    command, *options = arguments
    command = { 'a' => 'admin', 'h' => 'help', 'l' => 'libs', 'p' => 'projects', 'w' => 'workspaces' }.fetch(command, command)
    case command
    when 'admin' then return Admin.run_admin(options)
    when 'claude' then return Claude.run_claude(options)
    when 'codex' then return Codex.run_codex(options)
    when 'libs' then return Libraries.run_libraries(options)
    when 'projects' then return Projects.run_projects(options)
    when 'workspaces' then return Workspaces.run_workspaces(options)
    when 'help', '-h', '--help'
      if options.empty?
        puts GLOBAL_HELP
        return 0
      end
      warn "Unexpected help argument: #{options.first}"
    when nil then warn 'Missing command.'
    else warn "Unknown command: #{command}"
    end
    warn "\n#{GLOBAL_HELP}"
    2
  end
end
