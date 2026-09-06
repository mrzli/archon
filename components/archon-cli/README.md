# Archon CLI

Requires Bun on `PATH`. Build and run locally from the repository root:

```bash
NODE_ENV=development bun install --frozen-lockfile --cwd components/archon-cli
bun run --cwd components/archon-cli build
components/archon-cli/dist/bin/archon --help
```

Alternatively, build with `bun components/archon-cli/scripts/build.ts`.
Builds check TypeScript before emitting JavaScript. To check types alone, run
`bun run --cwd components/archon-cli typecheck`.

Setup installs the frozen development dependencies, builds, and installs the CLI
automatically. To install an already-built artifact separately:

```bash
mkdir -p "$HOME/.local"
rsync -a components/archon-cli/dist/ "$HOME/.local/"
```

This updates managed CLI files in `~/.local/bin` and `~/.local/lib/archon`.
Ensure `~/.local/bin` is on `PATH` to run `archon` and `arc`. The installed CLI
requires Bun and each command's external tools, but no TypeScript compiler or
development dependencies.

New dependency resolutions require releases at least three days old, with no
package exemptions. Locked versions are reused during setup and installation.

Archon provides one command for the workstation tools maintained by this
repository:

```text
archon projects <command> [options]
archon libs <command> [options]
archon workspaces <start|stop> [options]
archon workspaces kill
```

`arc` is an exact alias for `archon`, so `arc projects status` and
`archon projects status` are equivalent.

Direct subcommands also have one-letter aliases: `h` for `help`, `l` for
`libs`, `p` for `projects`, and `w` for `workspaces`. These work with both
`archon` and `arc`, for example:

```bash
arc p status
arc l build
arc w start
arc h
```

Aliases apply only to direct subcommands; nested commands keep their full names.

Commands use these exit statuses:

- `0`: the command completed successfully, including help and empty states.
- `1`: an operational failure occurred, such as a Git, GitHub, Bun, tmux,
  filesystem, or validation failure.
- `2`: the command syntax, operand, or option was invalid.

Detailed behavior is documented with each command collection:

- [Projects](./src/commands/projects/README.md)
- [Libraries](./src/commands/libs/README.md)
- [Workspaces](./src/commands/workspaces/README.md)
