require_relative '../../shared/process'
require_relative '../workspaces/project_selection'
require_relative 'hyprland'

module Archon
  module VisualStudioCode
    extend self

    HELP = <<~TEXT.chomp.freeze
      Usage: archon visual-studio-code <start|stop>
             archon vsc <start|stop>

      start  Choose a workspace and projects, then open a Hyprland tabbed group
      stop   Close ALL VS Code windows in the current Hyprland session

      Start requires an interactive terminal, Hyprland, hyprctl, and code on PATH.
      Projects are direct directories in ~/projects/cloned and ~/projects/personal/<owner>.
      Workspace and project selections are remembered for the next start.
      j/k or Up/Down: navigate. Space: toggle. Enter: accept. Esc or Ctrl+C: cancel.
      Workspace digits 1-9 and 0 (workspace 10) select a workspace; Enter accepts it.
    TEXT

    def run_visual_studio_code(arguments, home: Dir.home, state_home: ENV['XDG_STATE_HOME'],
                             run: Shared.method(:run_process), picker: WorkspaceProjects.method(:pick_projects),
                             launch: method(:launch_projects))
      if [%w[help], %w[-h], %w[--help], %w[help start], %w[help stop],
          %w[start -h], %w[start --help], %w[stop -h], %w[stop --help]].include?(arguments)
        puts HELP
        return 0
      end
      unless [%w[start], %w[stop]].include?(arguments)
        warn "Expected start or stop.\n\n#{HELP}"
        return 2
      end
      if arguments == ['stop']
        count = stop_windows(run: run)
        puts(count > 0 ? 'Closed all VS Code windows.' : 'No VS Code windows running.')
        return 0
      end

      projects = WorkspaceProjects.discover_projects(home)
      if projects.empty?
        puts 'No projects found under ~/projects/cloned or ~/projects/personal.'
        return 0
      end
      state_root = state_home.to_s.empty? ? File.join(home, '.local/state') : state_home
      state_path = File.join(state_root, 'archon/visual-studio-code.json')
      selection = picker.call(projects, WorkspaceProjects.load_selection(state_path, workspace: true), home: home, workspace: true)
      unless selection
        puts 'Cancelled.'
        return 0
      end
      WorkspaceProjects.save_selection(state_path, selection)
      if selection.fetch('projects').empty?
        puts 'No projects selected.'
        return 0
      end
      launch.call(selection.fetch('projects'), selection.fetch('workspace'), run: run)
      puts "Opened #{selection.fetch('projects').length} projects in workspace #{selection.fetch('workspace')}."
      0
    rescue Interrupt
      puts 'Cancelled.'
      130
    rescue StandardError => error
      warn "VS Code operation failed: #{error.message}"
      1
    end

  end
end
