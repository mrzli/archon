# Herdr workspaces command

```bash
archon workspaces herdr start
archon workspaces herdr start --ai codex
archon workspaces herdr stop
archon workspaces herdr restart
archon workspaces herdr restart --ai codex
archon workspaces herdr kill
archon workspaces herdr --help
```

Start chooses projects using the [shared project checklist](../README.md) and
gives each one a workspace labelled with the project folder name. Same-named
projects get separate workspaces. Workspace IDs are remembered in
`${XDG_STATE_HOME:-~/.local/state}/archon/workspaces/herdr.json`; keep this file
so later starts reuse the same workspaces. A workspace you renamed gets its
folder name back.

Repeated starts preserve existing workspaces and relaunch Neovim or the AI tool
in their single-pane tabs when only a bash prompt is running there. Running
programs and native agent restores are left alone. Failed creations roll back
their new resources, and later projects are still attempted.

Interactive starts outside Herdr attach in the current terminal and focus the
first selected project. Inside Herdr, the current view is preserved.

Everything runs in the dedicated Herdr session `archon`; start launches its
server when needed, first waiting up to 10 seconds for a session that is still
shutting down. Other Herdr sessions are unaffected.

## Stop

Stop shuts down the entire `archon` session, including workspaces you added
there, and keeps its saved layout. Stopping a stopped session succeeds. From a
Herdr pane it runs independently, so closing that pane does not interrupt it.

## Restart

Restart stops the `archon` session, waits until it has exited, then starts the
remembered project selection without showing the checklist. Saved layouts are
kept, as with stop and start. Outside Herdr it attaches afterwards. From a Herdr
pane it runs independently: your Herdr view closes, and a terminal attached by
`arc w h start` reattaches once the restart finishes. Otherwise, reattach with
`herdr --session archon`. With no remembered projects, it only stops the
session.

Logs are saved under `${XDG_STATE_HOME:-~/.local/state}/archon/`:
`workspaces-herdr-server.log` for the server and `workspaces-herdr-stop.log`
for stop, restart and kill.

## Kill

Stops **all Herdr sessions**, including sessions outside Archon, and clears
saved layouts for running and stopped sessions. The next start creates fresh
workspaces for the selected projects. Project files, shared Herdr
configuration, and the project checklist are preserved. Later sessions are
still attempted if one fails, and repeated kills succeed.
