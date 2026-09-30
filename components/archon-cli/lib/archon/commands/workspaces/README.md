# Workspaces command

Choose a backend explicitly. There is no default:

```bash
archon workspaces herdr start
archon workspaces tmux start
archon workspaces --help
```

`w` is an alias for `workspaces`. Backend aliases are `h` for `herdr` and `t`
for `tmux`; both work with `archon` and `arc`.

## Herdr

Requires Herdr on `PATH`, plus the tools used by the configured projects.
Manage workspaces in the dedicated Herdr session named `archon`:

```bash
arc w h start -g flashcards
arc w h stop
arc w h kill
arc w h --help
```

See [Herdr usage](./herdr/README.md) for prerequisites, options, and behavior.

## tmux

Requires tmux on `PATH`, plus the tools used by the configured projects.
Manage the configured tmux session groups:

```bash
arc w t start -g flashcards
arc w t stop
arc w t kill
arc w t --help
```

See [tmux usage](./tmux/README.md) for options and behavior. `kill` stops the
entire tmux server, including sessions outside Archon's workspace groups.
