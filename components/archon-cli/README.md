# Archon CLI

Requires Ruby on `PATH`. Run directly from the repository root:

```bash
components/archon-cli/bin/archon --help
```

Setup installs the CLI automatically. To install it separately:

```bash
mkdir -p "$HOME/.local/bin" "$HOME/.local/lib/archon"
rsync -a components/archon-cli/bin/ "$HOME/.local/bin/"
rsync -a --delete --exclude='*.md' components/archon-cli/lib/archon/ "$HOME/.local/lib/archon/"
```

This updates managed CLI files in `~/.local/bin` and `~/.local/lib/archon`.
Ensure `~/.local/bin` is on `PATH` to run `archon` and `arc`. The CLI needs
Ruby and each command's external tools. No build or gem installation is required.

Archon provides one command for the workstation tools maintained by this
repository:

```text
archon admin battery status
archon admin battery conservation <on|off>
archon admin github ssh <create|test>
archon admin voice <start|stop>
archon agents <reload|restart>
archon drives <eject|list>
archon projects <command> [options]
archon projects libs <build|graph>
archon setup
archon workspaces herdr <start|stop|kill> [options]
archon workspaces list
archon workspaces tmux <start|stop|kill> [options]
archon workspaces visual-studio-code <start|stop>
```

`arc` is an exact alias for `archon`, so `arc projects status` and
`archon projects status` are equivalent.

Direct subcommands also have short aliases: `a` for `admin`, `d` for `drives`, `g` for `agents`, `h` for `help`,
`p` for `projects`, and `w` for `workspaces`. These work with both `archon` and `arc`, for example:

```bash
arc a voice stop
arc g reload
arc d eject
arc p status
arc p libs build
arc w vsc start
arc w vsc stop
arc w h start
arc w t start --ai claude
arc h
```

Workspace lifecycle commands require a backend: `herdr` (alias `h`), `tmux`
(alias `t`), or `visual-studio-code` (alias `vsc`). There is no default backend.
`workspaces list` shows discovered project directories without a backend. Other nested commands keep their full names.

`archon setup` runs `setup.sh` from the Archon checkout at
`~/projects/personal/mrzli/archon`, from any directory. To restart running agent
sessions afterwards as well, use `archon agents reload`.

Commands use these exit statuses:

- `0`: the command completed successfully, including help and empty states.
- `1`: an operational failure occurred, such as a Git, GitHub, Bun, tmux, Herdr,
  filesystem, or validation failure.
- `2`: the command syntax, operand, or option was invalid.

Detailed behavior is documented with each command collection:

- [Administration](./lib/archon/commands/admin/README.md)
- [Agents](./lib/archon/commands/agents/README.md)
- [Drives](./lib/archon/commands/drives/README.md)
- [Projects](./lib/archon/commands/projects/README.md), including
  [libraries](./lib/archon/commands/projects/libs/README.md)
- [Workspaces](./lib/archon/commands/workspaces/README.md)
