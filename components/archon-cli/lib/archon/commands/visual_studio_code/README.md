# Visual Studio Code

Requires Ruby, an interactive terminal, a running Hyprland session with Lua
configuration (as used by current Omarchy), and `code` and `hyprctl` on `PATH`.

## Start

```bash
archon visual-studio-code start
arc vsc start
```

Choose a workspace, then select projects in the terminal checklist.
The action is required; `arc vsc` shows usage and exits with status 2.
Use `arc vsc --help` for help. The controls are shown in both prompts:

- `j`/`k` or Up/Down moves the cursor.
- Workspace digits `1`–`9` and `0` select a workspace. `0` means workspace 10.
- Space toggles the highlighted project.
- Enter accepts the workspace or project selection.
- Escape cancels the entire selection without opening windows or saving changes.
- Ctrl+C cancels and restores the terminal.

Git repositories are discovered recursively under `~/projects/clone` and
`~/projects/personal`, including worktrees with a `.git` file. Discovery stops
at each repository root and does not follow directory symlinks. Missing roots
are treated as empty. Paths relative to `~/projects` are shown alphabetically.

The workspace and selected paths are saved in
`${XDG_STATE_HOME:-~/.local/state}/archon/visual-studio-code.json` when you accept
the project checklist. The next start restores those choices; removed projects
are omitted and new projects start unchecked. Accepting an empty selection
saves it and opens nothing.

Each selected project opens in a new VS Code window, using your existing
settings and extensions. Windows open in checklist order and form one Hyprland
tabbed group on the chosen workspace. The first project is focused when done.
Existing VS Code windows are preserved. Starting again opens a new group.

The command briefly uses a temporary named workspace while assembling the
group. If opening or grouping fails, windows already opened are moved to the
chosen workspace and the command reports the failure. Group locks or window
rules that prevent grouping must be resolved before retrying.

## Stop

```bash
archon visual-studio-code stop
arc vsc stop
```

Closes **all VS Code windows in the current Hyprland session**, including windows
opened outside this command. It uses normal window-close requests so VS Code
can save its state and shut down its helper processes. It waits up to 30 seconds
for the windows to close and succeeds when no matching windows are open.

VS Code's configured shutdown confirmations are respected. If windows remain
open, the command reports a failure instead of forcefully terminating them.
Saved selections are preserved. Stop also requires Hyprland and `hyprctl`.
