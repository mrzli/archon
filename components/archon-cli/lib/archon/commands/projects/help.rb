require_relative 'libs/help'
require_relative 'secrets/help'

module Archon
  module Projects
    HELP = {
      'delete' => <<~TEXT.chomp,
        Usage: archon projects delete [options]

        Permanently delete every local <owner>/<repository>.

        Options:
          -n, --dry-run  List repositories without deleting them
          -h, --help     Show help for this command
      TEXT
      'libs' => Libraries::HELP.fetch('global'),
      'prune' => <<~TEXT.chomp,
        Usage: archon projects prune [options]

        Delete local repositories that no longer exist remotely.

        Options:
          -n, --dry-run  List repositories without deleting them
          -h, --help     Show help for this command
      TEXT
      'remote' => <<~TEXT.chomp,
        Usage: archon projects remote [options]

        List included repositories owned by the authenticated GitHub user.

        Options:
          -h, --help  Show help for this command
      TEXT
      'secrets' => Secrets::HELP.fetch('global'),
      'status' => <<~TEXT.chomp,
        Usage: archon projects status [options]

        Show concise local Git status for every owner/repository.

        Options:
          --fetch      Fetch and prune all remotes before showing status
          -h, --help   Show help for this command
      TEXT
      'sync' => <<~TEXT.chomp,
        Usage: archon projects sync [options]

        Update existing local repositories and clone missing remote repositories.

        Options:
          -h, --help  Show help for this command
      TEXT
      'help' => <<~TEXT.chomp,
        Usage: archon projects help [command]

        Show global help or detailed help for one command.
      TEXT
      'global' => <<~TEXT.chomp
        Usage: archon projects <command>

        Commands:
          delete   Delete all local repositories inside personal
          libs     Build or graph local @mrzli-jslib/* packages
          prune    Delete local repositories that no longer exist remotely
          remote   List included repositories owned by the GitHub user
          secrets  Generate .env files from a central secrets store
          status   Show concise local Git status for every repository
          sync     Update existing repositories and clone missing repositories
          help     Show global or command-specific help

        Run "archon projects help <command>" for detailed command help.
      TEXT
    }.freeze
  end
end
