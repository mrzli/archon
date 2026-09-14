require_relative 'commands/libs/libs'
require_relative 'commands/projects/projects'
require_relative 'commands/workspaces/workspaces'
require_relative 'commands/workspaces_herdr/workspaces_herdr'

module Archon
  extend self

  GLOBAL_HELP = <<~TEXT.chomp.freeze
    Usage: archon <command> [options]

    Commands:
      help (h)                 Show this help
      libs (l)                 Manage local JavaScript libraries
      projects (p)             Manage personal project repositories
      workspaces (w)           Manage tmux workspace sessions
      workspaces-herdr (wh)     Manage Herdr workspaces
  TEXT

  def main(arguments)
    command, *options = arguments
    command = { 'h' => 'help', 'l' => 'libs', 'p' => 'projects', 'w' => 'workspaces', 'wh' => 'workspaces-herdr' }.fetch(command, command)
    case command
    when 'libs' then return Libraries.run_libraries(options)
    when 'projects' then return Projects.run_projects(options)
    when 'workspaces' then return Workspaces.run_workspaces(options)
    when 'workspaces-herdr' then return WorkspacesHerdr.run_workspaces_herdr(options)
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
