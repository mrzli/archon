require_relative '../../shared/process'

module Archon
  module Libraries
    extend self
    LOCAL_PACKAGE_SCOPE = '@mrzli-jslib'
    DEPENDENCY_FIELDS = %w[dependencies devDependencies optionalDependencies peerDependencies].freeze

    def dependency_graph(repositories)
      packages = repositories.map { |repository| read_package(repository) }
      by_name = {}
      by_path = {}
      packages.each do |package|
        raise "duplicate package name \"#{package[:name]}\"" if by_name.key?(package[:name])
        by_name[package[:name]] = package
        by_path[package[:path]] = package
      end
      packages.map { |package| package.merge(dependencies: package_dependencies(package, by_path)) }
    end

    def read_package(repository)
      begin
        manifest = JSON.parse(File.read(File.join(repository[:path], 'package.json')))
      rescue StandardError => error
        raise "#{repository[:name]}/package.json could not be read: #{error.message}"
      end
      unless manifest.is_a?(Hash) && manifest['name'].is_a?(String) && manifest['name'].start_with?("#{LOCAL_PACKAGE_SCOPE}/")
        raise "#{repository[:name]}/package.json must have a name in the #{LOCAL_PACKAGE_SCOPE} scope"
      end
      { name: manifest['name'], manifest: manifest, path: File.realpath(repository[:path]) }
    end

    def package_dependencies(package, by_path)
      dependencies = Set.new
      DEPENDENCY_FIELDS.each do |field|
        next unless package[:manifest].key?(field)
        entries = package[:manifest][field]
        raise "#{package[:name]} has an invalid #{field} field" unless entries.is_a?(Hash)
        entries.each do |name, specifier|
          next unless name.start_with?("#{LOCAL_PACKAGE_SCOPE}/")
          unless specifier.is_a?(String) && specifier.start_with?('file:')
            raise "#{package[:name]} declares #{name} in #{field} with \"#{specifier}\"; local packages must use the file: protocol"
          end
          path = specifier.delete_prefix('file:')
          raise "#{package[:name]} declares an empty path for #{name}" if path.empty?
          begin
            resolved = File.realpath(File.expand_path(path, package[:path]))
          rescue StandardError => error
            raise "#{package[:name]} declares #{name} at #{specifier}, but that path could not be resolved: #{error.message}"
          end
          dependency = by_path[resolved]
          raise "#{package[:name]} declares #{name} at #{specifier}, but that directory is not a local repository" unless dependency
          unless dependency[:name] == name
            raise "#{package[:name]} declares #{name} at #{specifier}, but that package is named #{dependency[:name]}"
          end
          dependencies.add(name)
        end
      end
      dependencies.to_a.sort
    end

    def order_packages(graph)
      by_name = graph.to_h { |node| [node[:name], node] }
      states = {}
      path = []
      ordered = []
      visit = lambda do |node|
        name = node[:name]
        next if states[name] == :visited
        if states[name] == :visiting
          raise "dependency cycle detected: #{(path[path.index(name)..] + [name]).join(' -> ')}"
        end
        states[name] = :visiting
        path << name
        node[:dependencies].each { |dependency| visit.call(by_name.fetch(dependency)) }
        path.pop
        states[name] = :visited
        ordered << node
      end
      graph.each { |node| visit.call(node) }
      ordered
    end

    def validate_build_scripts(graph)
      graph.each do |node|
        scripts = node[:manifest]['scripts']
        unless scripts.is_a?(Hash) && scripts['build'].is_a?(String) && !scripts['build'].empty?
          raise "#{node[:name]} must define a non-empty build script"
        end
      end
    end

    def run_packages(command, root)
      begin
        graph = dependency_graph(local_repositories(root))
        if command == 'build'
          validate_build_scripts(graph)
          graph = order_packages(graph)
        end
      rescue StandardError => error
        warn "Could not #{command == 'build' ? 'prepare build' : 'generate dependency graph'}: #{error.message}"
        return 1
      end
      if graph.empty?
        puts empty_message(root)
        return 0
      end
      if command == 'graph'
        graph.each do |node|
          puts node[:name]
          node[:dependencies].each { |dependency| puts "  -> #{dependency}" }
        end
        return 0
      end
      graph.each_with_index do |package, index|
        puts "[#{index + 1}/#{graph.length}] #{package[:name]}"
        return 1 unless run_bun(package, %w[install --frozen-lockfile --ignore-scripts], 'install dependencies')
        return 1 unless run_bun(package, %w[run build], 'build package')
      end
      puts "Built #{graph.length} packages."
      0
    end

    def run_bun(package, arguments, action)
      result = Shared.run_process('bun', arguments, cwd: package[:path], stdio: :inherit)
      error = if result[:error]
                result[:error].message
              elsif result[:signal]
                "Bun was terminated by signal #{result[:signal]}"
              elsif result[:status] != 0
                "Bun exited with status #{result[:status] || 'unknown'}"
              end
      warn "#{package[:name]}: could not #{action}: #{error}" if error
      error.nil?
    end
  end
end
