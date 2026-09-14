module Archon
  module Libraries
    HELP = {
      'build' => <<~TEXT.chomp,
        Usage: archon libs build [options]

        Build local @mrzli-jslib/* packages in dependency order.

        Installs from each frozen Bun lockfile without running lifecycle scripts.

        Options:
          -h, --help  Show help for this command
      TEXT
      'delete' => <<~TEXT.chomp,
        Usage: archon libs delete [options]

        Permanently delete every local Git repository in this directory.

        Options:
          -n, --dry-run  List repositories without deleting them
          -h, --help     Show help for this command
      TEXT
      'graph' => <<~TEXT.chomp,
        Usage: archon libs graph [options]

        Show dependencies between local @mrzli-jslib/* packages.

        Local package dependencies must use the file: protocol.

        Options:
          -h, --help  Show help for this command
      TEXT
      'prune' => <<~TEXT.chomp,
        Usage: archon libs prune [options]

        Delete local repositories that no longer exist remotely.

        Options:
          -n, --dry-run  List repositories without deleting them
          -h, --help     Show help for this command
      TEXT
      'remote' => <<~TEXT.chomp,
        Usage: archon libs remote [options]

        List repositories owned by the mrzli-jslib GitHub organization.

        Options:
          -h, --help  Show help for this command
      TEXT
      'status' => <<~TEXT.chomp,
        Usage: archon libs status [options]

        Show concise local Git status for every repository.

        Options:
          --fetch      Fetch and prune all remotes before showing status
          -h, --help   Show help for this command
      TEXT
      'sync' => <<~TEXT.chomp,
        Usage: archon libs sync [options]

        Update existing local repositories and clone missing remote repositories.

        Options:
          -h, --help  Show help for this command
      TEXT
      'help' => <<~TEXT.chomp,
        Usage: archon libs help [command]

        Show global help or detailed help for one command.
      TEXT
      'global' => <<~TEXT.chomp
        Usage: archon libs <command>

        Commands:
          build   Build local @mrzli-jslib/* packages in dependency order
          delete  Delete all local Git repositories inside mrzli-jslib
          graph   Show dependencies between local @mrzli-jslib/* packages
          prune   Delete local repositories that no longer exist remotely
          remote  List repositories owned by the mrzli-jslib GitHub organization
          status  Show concise local Git status for every repository
          sync    Update existing repositories and clone missing repositories
          help    Show global or command-specific help

        Run "archon libs help <command>" for detailed command help.
      TEXT
    }.freeze
  end
end
