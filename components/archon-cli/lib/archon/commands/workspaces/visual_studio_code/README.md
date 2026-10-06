# Visual Studio Code

Requires Ruby, current VS Code, an interactive terminal, a running Hyprland
session with Lua configuration (as used by current Omarchy), and `code` and
`hyprctl` on `PATH`.

## Start

```bash
archon workspaces visual-studio-code start
arc w vsc start
```

Choose a workspace, then select projects in the terminal checklist.
The action is required; `arc w vsc` shows usage and exits with status 2.
Use `arc w vsc --help` for help. The controls are shown in both prompts:

- `j`/`k` or Up/Down moves the cursor.
- Workspace digits `1`–`9` and `0` select a workspace. `0` means workspace 10.
- Space toggles the highlighted project.
- Enter accepts the workspace or project selection.
- Escape cancels the entire selection without opening windows or saving changes.
- Ctrl+C cancels and restores the terminal.

Projects and saved choices work as described in the
[shared project checklist](../README.md); the chosen workspace is remembered
with them.

Each selected project opens in a new VS Code window, using your existing
settings and extensions. Windows open in checklist order and form one Hyprland
tabbed group on the chosen workspace. The first project is focused when done.
Existing VS Code windows are preserved. Starting again opens a new group.

While assembling the group, windows briefly appear on a temporary named
workspace. If opening or grouping fails, windows already opened are moved to
the chosen workspace and the failure is reported. Group locks or window rules
that prevent grouping must be resolved before retrying.

## Stop

```bash
archon workspaces visual-studio-code stop
arc w vsc stop
```

Closes **all VS Code windows in the current Hyprland session**, including windows
opened outside this command. It uses normal window-close requests so VS Code
can save its state and shut down its helper processes. It waits up to 30 seconds
for the windows to close and succeeds when no matching windows are open.

VS Code's configured shutdown confirmations are respected. If windows remain
open, the command reports a failure instead of forcefully terminating them.
Saved selections are preserved. Stop also requires Hyprland and `hyprctl`.
