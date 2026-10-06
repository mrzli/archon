require_relative 'help'
require_relative 'build'

module Archon
  module Libraries
    def run_libraries(arguments, home: Dir.home)
      command, *options = arguments
      if %w[help --help -h].include?(command)
        return library_help(options)
      end
      unless %w[build graph].include?(command)
        warn(command ? "Unknown libs command: #{command}" : 'Missing libs command.')
        warn HELP.fetch('global')
        return 2
      end
      if options.length == 1 && %w[-h --help].include?(options.first)
        puts HELP.fetch(command)
        return 0
      end
      unless options.empty?
        warn "Unexpected #{command} option: #{options.first}"
        warn HELP.fetch(command)
        return 2
      end
      run_packages(command, File.expand_path('projects/personal/mrzli-jslib', home))
    rescue StandardError => error
      warn "Unexpected error: #{error.message}"
      1
    end

    def library_help(options)
      if options.empty?
        puts HELP.fetch('global')
      elsif options.length == 1 && %w[build graph].include?(options.first)
        puts HELP.fetch(options.first)
      elsif options.length == 1 && %w[help -h --help].include?(options.first)
        puts HELP.fetch('help')
      else
        warn(options.length > 1 ? "Unexpected help argument: #{options[1]}" : "Unknown libs command: #{options.first}")
        warn HELP.fetch('help')
        return 2
      end
      0
    end

    def empty_message(root)
      "No local Git repositories found in #{root}."
    end

    def local_repositories(root)
      Shared.child_repositories(root).sort_by { |repository| repository.fetch(:name) }
    rescue Errno::ENOENT
      []
    end
  end
end
