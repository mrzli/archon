# Archon CLI

Requires Ruby on `PATH`. Run directly from the repository root:

```bash
components/archon-cli/bin/archon --help
```

Setup installs the CLI automatically. To install it separately:

```bash
mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"
rsync -a components/archon-cli/bin/ "$HOME/.local/bin/"
rsync -a --exclude='*.md' components/archon-cli/lib/ "$HOME/.local/lib/"
```

This updates managed CLI files in `~/.local/bin` and `~/.local/lib/archon`.
Ensure `~/.local/bin` is on `PATH` to run `archon` and `arc`. The CLI needs
Ruby and each command's external tools. No build or gem installation is required.

Archon provides one command for the workstation tools maintained by this
repository:

```text
archon libs <command> [options]
archon projects <command> [options]
archon workspaces <start|stop> [options]
archon workspaces kill
archon workspaces-herdr <start|stop> [options]
archon workspaces-herdr kill
```

`arc` is an exact alias for `archon`, so `arc projects status` and
`archon projects status` are equivalent.

Direct subcommands also have short aliases: `h` for `help`, `l` for
`libs`, `p` for `projects`, `w` for `workspaces`, and `wh` for
`workspaces-herdr`. These work with both
`archon` and `arc`, for example:

```bash
arc p status
arc l build
arc w start
arc wh start -g flashcards
arc h
```

Aliases apply only to direct subcommands; nested commands keep their full names.

Commands use these exit statuses:

- `0`: the command completed successfully, including help and empty states.
- `1`: an operational failure occurred, such as a Git, GitHub, Bun, tmux, Herdr,
  filesystem, or validation failure.
- `2`: the command syntax, operand, or option was invalid.

Detailed behavior is documented with each command collection:

- [Libraries](./lib/archon/commands/libs/README.md)
- [Projects](./lib/archon/commands/projects/README.md)
- [Workspaces](./lib/archon/commands/workspaces/README.md)
- [Herdr workspaces](./lib/archon/commands/workspaces_herdr/README.md)
