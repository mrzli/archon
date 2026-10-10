module Archon
  module Secrets
    HELP = {
      'init' => <<~TEXT.chomp,
        Usage: archon projects secrets init [options]

        Create the secrets store, or add secret names missing from it.

        Existing entries and values are never changed.

        Options:
          -h, --help  Show help for this command
      TEXT
      'sync' => <<~TEXT.chomp,
        Usage: archon projects secrets sync [options]

        Render each repository's .env*.template files into gitignored .env* files.

        Options:
          -h, --help  Show help for this command
      TEXT
      'help' => <<~TEXT.chomp,
        Usage: archon projects secrets help [command]

        Show secrets help or detailed help for one secrets command.
      TEXT
      'global' => <<~TEXT.chomp
        Usage: archon projects secrets <command>

        Commands:
          init    Create the secrets store or add missing secret names
          sync    Render .env*.template files into .env* files
          help    Show secrets help or command-specific help

        The store is ${XDG_DATA_HOME:-~/.local/share}/archon/secrets/secrets.env.
      TEXT
    }.freeze
  end
end
