require 'find'
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
      stop   Stop ALL VS Code processes owned by the current user

      Start requires an interactive terminal, Hyprland, hyprctl, and code on PATH.
      Projects are Git repositories under ~/projects/clone and ~/projects/personal.
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
        result = run.call('pkill', ['-TERM', '-u', Process.uid.to_s, '-x', 'code'])
        raise result[:error] if result[:error]
        raise 'Could not stop VS Code.' if result[:signal] || ![0, 1].include?(result[:status])
        puts(result[:status] == 0 ? 'Stopped all VS Code processes for this user.' : 'No VS Code processes running.')
        return 0
      end

      projects = discover_projects(home)
      if projects.empty?
        puts 'No Git repositories found under ~/projects/clone or ~/projects/personal.'
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
      %w[clone personal].flat_map do |name|
        root = File.join(home, 'projects', name)
        next [] unless File.exist?(root)
        projects = []
        Find.find(root) do |path|
          Find.prune if File.symlink?(path)
          next unless File.directory?(path)
          if File.directory?(File.join(path, '.git')) || File.file?(File.join(path, '.git'))
            projects << path
            Find.prune
          end
        end
        projects
      end.sort
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
