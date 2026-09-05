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

Commands use these exit statuses:

- `0`: the command completed successfully, including help and empty states.
- `1`: an operational failure occurred, such as a Git, GitHub, Bun, tmux,
  filesystem, or validation failure.
- `2`: the command syntax, operand, or option was invalid.

Detailed behavior is documented with each command collection:

- [Projects](./lib/archon/projects/README.md)
- [Libraries](./lib/archon/libs/README.md)
- [Workspaces](./lib/archon/workspaces/README.md)
