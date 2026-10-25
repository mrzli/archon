require_relative 'commands/admin/admin'
require_relative 'commands/agents/agents'
require_relative 'commands/drives/drives'
require_relative 'commands/projects/projects'
require_relative 'commands/workspaces/workspaces'

module Archon
  extend self

  GLOBAL_HELP = <<~TEXT.chomp.freeze
    Usage: archon <command> [options]

    Commands:
      admin (a)                 Manage workstation services
      agents (g)                Restart Claude Code and Codex CLI sessions
      drives (d)                List or eject removable drives
      help (h)                  Show this help
      projects (p)              Manage personal project repositories
      workspaces (w)            Manage Herdr, tmux, or VS Code workspaces
  TEXT

  def main(arguments)
    command, *options = arguments
    command = { 'a' => 'admin', 'd' => 'drives', 'g' => 'agents', 'h' => 'help', 'p' => 'projects', 'w' => 'workspaces' }.fetch(command, command)
    case command
    when 'admin' then return Admin.run_admin(options)
    when 'agents' then return Agents.run_agents(options)
    when 'drives' then return Drives.run_drives(options)
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
