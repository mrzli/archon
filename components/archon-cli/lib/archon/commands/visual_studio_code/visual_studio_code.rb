require 'tempfile'
require_relative '../../shared/process'
require_relative 'picker'
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
                             run: Shared.method(:run_process), picker: method(:pick_projects),
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

      projects = discover_projects(home)
      if projects.empty?
        puts 'No projects found under ~/projects/cloned or ~/projects/personal.'
        return 0
      end
      state_root = state_home.to_s.empty? ? File.join(home, '.local/state') : state_home
      state_path = File.join(state_root, 'archon/visual-studio-code.json')
      selection = picker.call(projects, load_selection(state_path), home: home)
      unless selection
        puts 'Cancelled.'
        return 0
      end
      save_selection(state_path, selection)
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

    def discover_projects(home)
      cloned = File.join(home, 'projects/cloned')
      personal = File.join(home, 'projects/personal')
      (project_directories(cloned) + project_directories(personal).flat_map { |owner| project_directories(owner) }).sort
    end

    def project_directories(root)
      return [] unless File.directory?(root) && !File.symlink?(root)
      Dir.children(root).map { |name| File.join(root, name) }
         .select { |path| File.directory?(path) && !File.symlink?(path) }
    end

    def load_selection(path)
      return { 'workspace' => 1, 'projects' => [] } unless File.exist?(path)
      selection = JSON.parse(File.read(path))
      unless selection.is_a?(Hash) && selection['workspace'].is_a?(Integer) && (1..10).include?(selection['workspace']) &&
             selection['projects'].is_a?(Array) && selection['projects'].all? { |project| project.is_a?(String) }
        raise "Invalid saved selection: #{path}"
      end
      selection
    end

    def save_selection(path, selection)
      FileUtils.mkdir_p(File.dirname(path))
      Tempfile.create(['visual-studio-code', '.json'], File.dirname(path)) do |file|
        file.write("#{JSON.pretty_generate(selection)}\n")
        file.close
        File.rename(file.path, path)
      end
    end
  end
end
