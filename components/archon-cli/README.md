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
archon admin battery status
archon admin battery conservation <on|off>
archon admin github ssh <create|test>
archon admin voice <start|stop>
archon codex restart
archon libs <command> [options]
archon projects <command> [options]
archon visual-studio-code <start|stop>
archon workspaces herdr <start|stop|kill> [options]
archon workspaces list
archon workspaces tmux <start|stop|kill> [options]
```

`arc` is an exact alias for `archon`, so `arc projects status` and
`archon projects status` are equivalent.

Direct subcommands also have short aliases: `a` for `admin`, `h` for `help`, `l` for
`libs`, `p` for `projects`, `vsc` for `visual-studio-code`, and `w` for
`workspaces`. These work with both `archon` and `arc`, for example:

```bash
arc a voice stop
arc p status
arc l build
arc vsc start
arc vsc stop
arc w h start
arc w t start --ai claude
arc h
```

Workspace lifecycle commands require a backend: `herdr` (alias `h`) or `tmux`
(alias `t`). There is no default backend. `workspaces list` shows discovered project directories
without a backend. Other nested commands keep their full names.

Commands use these exit statuses:

- `0`: the command completed successfully, including help and empty states.
- `1`: an operational failure occurred, such as a Git, GitHub, Bun, tmux, Herdr,
  filesystem, or validation failure.
- `2`: the command syntax, operand, or option was invalid.

Detailed behavior is documented with each command collection:

- [Administration](./lib/archon/commands/admin/README.md)
- [Codex](./lib/archon/commands/codex/README.md)
- [Libraries](./lib/archon/commands/libs/README.md)
- [Projects](./lib/archon/commands/projects/README.md)
- [Visual Studio Code](./lib/archon/commands/visual_studio_code/README.md)
- [Workspaces](./lib/archon/commands/workspaces/README.md)
