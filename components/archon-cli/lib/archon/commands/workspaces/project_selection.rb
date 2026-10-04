require 'fileutils'
require 'json'
require 'tempfile'
require_relative 'project_picker'

module Archon
  module WorkspaceProjects
    extend self

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

    def load_selection(path, workspace: false)
      return workspace ? { 'workspace' => 1, 'projects' => [] } : { 'projects' => [] } unless File.exist?(path)
      selection = JSON.parse(File.read(path))
      unless selection.is_a?(Hash) && selection['projects'].is_a?(Array) &&
             selection['projects'].all? { |project| project.is_a?(String) } &&
             (!workspace || (selection['workspace'].is_a?(Integer) && (1..10).include?(selection['workspace'])))
        raise "Invalid saved selection: #{path}"
      end
      selection
    end

    def save_selection(path, selection)
      FileUtils.mkdir_p(File.dirname(path))
      Tempfile.create(['selection', '.json'], File.dirname(path)) do |file|
        file.write("#{JSON.pretty_generate(selection)}\n")
        file.close
        File.rename(file.path, path)
      end
    end
  end
end
