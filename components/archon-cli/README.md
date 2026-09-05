# Archon CLI

Archon provides one command for the workstation tools maintained by this
repository:

```text
archon projects <command> [options]
archon libs <command> [options]
archon workspaces <start|stop> [options]
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

- [Projects](./lib/archon/projects/README.md)
- [Libraries](./lib/archon/libs/README.md)
- [Workspaces](./lib/archon/workspaces/README.md)
