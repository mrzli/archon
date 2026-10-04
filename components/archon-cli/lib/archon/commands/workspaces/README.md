# Workspaces command

List available projects or choose a backend explicitly. There is no default backend.
`w` aliases `workspaces`, `h` aliases `herdr`, and `t` aliases `tmux`.

Every direct directory under `~/projects/cloned` is a project. Under
`~/projects/personal`, each directory directly under an owner or organization
is a project. Discovery does not search deeper, require Git, or follow directory
symlinks. All backends share this discovery and project checklist.

## Herdr

Requires Herdr, Neovim and the selected AI tool on `PATH`.

```bash
arc w h start
arc w h start --ai claude
arc w h stop
arc w h --help
```

See [Herdr usage](./herdr/README.md).

## List

List discovered paths alphabetically without starting a backend:

```bash
archon workspaces list
arc w list
```

Missing roots are treated as empty. Listing takes no options except help.

## tmux

Requires tmux, Neovim and the selected AI tool on `PATH`.

```bash
arc w t start
arc w t start --ai claude
arc w t stop
arc w t --help
```

See [tmux usage](./tmux/README.md).

Start requires an interactive terminal. Use `j`/`k` or Up/Down to move, Space to
toggle projects, and Enter to accept. Escape or Ctrl+C cancels without saving.
There is no desktop workspace prompt for terminal backends.

Selections are remembered independently in
`${XDG_STATE_HOME:-~/.local/state}/archon/herdr.json` and `tmux.json`.
Removed projects are omitted and new ones start unchecked. An accepted empty
selection is saved and opens nothing. Existing sessions survive a later start
with a different selection. Each project has Neovim, the selected AI tool
(Codex by default, or Claude), and a shell. Development servers are not started.
