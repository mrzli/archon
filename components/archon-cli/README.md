# Archon CLI

Archon provides one command for the workstation tools maintained by this
repository:

```text
archon projects <command> [options]
archon libs <command> [options]
archon workspaces <start|stop> [options]
```

`a` is an exact alias for `archon`, so `a projects status` and
`archon projects status` are equivalent.

Direct subcommands also have one-letter aliases: `h` for `help`, `l` for
`libs`, `p` for `projects`, and `w` for `workspaces`. These work with both
`archon` and `a`, for example:

```bash
a p status
a l build
a w start
a h
```

Aliases apply only to direct subcommands; nested commands keep their full names.

Commands use these exit statuses:

- `0`: the command completed successfully, including help and empty states.
- `1`: an operational failure occurred, such as a Git, GitHub, Bun, tmux,
  filesystem, or validation failure.
- `2`: the command syntax, operand, or option was invalid.

Detailed behavior is documented with each command collection:

- [Projects](./lib/archon/projects/README.md)
- [Libraries](./lib/archon/libs/README.md)
- [Workspaces](./lib/archon/workspaces/README.md)
