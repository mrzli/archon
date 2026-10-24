# Workspaces command

List available projects or choose a backend explicitly. There is no default backend.
`w` aliases `workspaces`, `h` aliases `herdr`, and `t` aliases `tmux`.

Every direct directory under `~/projects/cloned` is a project. Under
`~/projects/personal`, each directory directly under an owner or organization
is a project. Discovery does not search deeper, require Git, or follow directory
symlinks. All backends share this discovery and project checklist.

Terminal backend start requires an interactive terminal. Use `j`/`k` or Up/Down
to move, Space to toggle projects, and Enter to accept. Escape or Ctrl+C cancels
without saving.
There is no desktop workspace prompt for terminal backends.

Selections are remembered independently under
`${XDG_STATE_HOME:-~/.local/state}/archon/workspaces/`:

- `herdr.json`: Herdr project selection.
- `tmux.json`: tmux project selection.
- `visual-studio-code.json`: VS Code workspace and project selection.

Each backend starts with no projects selected when its file does not exist.
Removed projects are omitted and new ones start unchecked. An accepted empty
selection is saved and opens nothing. For terminal backends, existing sessions
survive a later start with a different selection.

Each terminal project has tabs for Neovim, lazygit, a shell, and an AI tool.
`--ai claude` is the default and runs `claude --continue`, or `claude` when the
project has no saved conversation; `--ai codex` runs `codex resume --last`. The
tool must be on `PATH`, and the option applies to newly created workspaces.
Development servers are not started.

## Herdr

Requires Herdr, Neovim, lazygit and the selected AI tool on `PATH`.

```bash
arc w h start
arc w h start --ai codex
arc w h stop
arc w h restart
arc w h kill
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

Requires tmux, Neovim, lazygit and the selected AI tool on `PATH`.

```bash
arc w t start
arc w t start --ai codex
arc w t stop
arc w t restart
arc w t kill
arc w t --help
```

See [tmux usage](./tmux/README.md).

## Visual Studio Code

Requires an interactive terminal, Hyprland, `hyprctl`, and `code` on `PATH`.
`vsc` aliases `visual-studio-code` within `workspaces`.

```bash
archon workspaces visual-studio-code start
arc w vsc start
arc w vsc stop
arc w vsc --help
```

Choose a Hyprland workspace, then projects in the shared checklist. Stop closes
all VS Code windows in the current Hyprland session. See
[Visual Studio Code usage](./visual_studio_code/README.md).
