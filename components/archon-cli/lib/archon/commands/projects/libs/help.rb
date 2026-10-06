module Archon
  module Libraries
    HELP = {
      'build' => <<~TEXT.chomp,
        Usage: archon projects libs build [options]

        Build local @mrzli-jslib/* packages in dependency order.

        Installs from each frozen Bun lockfile without running lifecycle scripts.

        Options:
          -h, --help  Show help for this command
      TEXT
      'graph' => <<~TEXT.chomp,
        Usage: archon projects libs graph [options]

        Show dependencies between local @mrzli-jslib/* packages.

        Local package dependencies must use the file: protocol.

        Options:
          -h, --help  Show help for this command
      TEXT
      'help' => <<~TEXT.chomp,
        Usage: archon projects libs help [command]

        Show libs help or detailed help for one libs command.
      TEXT
      'global' => <<~TEXT.chomp
        Usage: archon projects libs <command>

        Commands:
          build   Build local @mrzli-jslib/* packages in dependency order
          graph   Show dependencies between local @mrzli-jslib/* packages
          help    Show libs help or command-specific help

        Packages are the repositories in ~/projects/personal/mrzli-jslib.
        Use archon projects sync to clone and update them.
      TEXT
    }.freeze
  end
end
