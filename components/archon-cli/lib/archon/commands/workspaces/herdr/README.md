# Herdr workspaces command

```bash
archon workspaces herdr start
archon workspaces herdr start --ai claude
archon workspaces herdr stop
archon workspaces herdr --help
```

Start chooses projects using the [shared project checklist](../README.md).
Each project has Neovim, an AI tool, and a shell. `--ai codex` is the default
and runs `codex resume --last`; `--ai claude` runs `claude --continue`.
The tool must be on `PATH`. The option affects newly created workspaces.
Repeated starts preserve existing workspaces and relaunch Neovim or the AI tool
in their existing, single-pane tabs when only a shell is running. Running
programs and native agent restores are left alone. This also applies after
stop/start and when starting from inside Herdr. Failed creations roll back
their new resources and later projects are still attempted.

Workspace labels are just the project folder name. Same-named projects have
separate workspaces. Start also shortens selected workspaces' labels created by
earlier Archon versions. Workspace IDs are remembered alongside the project selection in
`${XDG_STATE_HOME:-~/.local/state}/archon/workspaces/herdr.json`; keep this file
to reuse the correct workspaces on later starts.

Interactive starts outside Herdr attach in the current terminal and focus the
first selected project. Inside Herdr, the current view is preserved.
Stop never attaches or prompts.

Stop from a Herdr pane runs independently so closing that pane does not
interrupt the remaining work. Shutdown diagnostics are saved in
`${XDG_STATE_HOME:-~/.local/state}/archon/workspaces-herdr-stop.log`.

Uses the dedicated Herdr session `archon`. Start launches its background server
when needed. Stop shuts down this entire session, including extra workspaces
you added there, and preserves its saved layout. Other Herdr sessions are
unaffected. Stopping an already stopped session succeeds. Server diagnostics
are saved in `archon/workspaces-herdr-server.log` under the state directory.

## Kill

```bash
arc w h kill
```

Stops **all Herdr sessions**, including sessions outside Archon, and clears
saved layouts for running and stopped sessions. The next start creates fresh
workspaces for the selected projects and launches their tools. Project files,
shared Herdr configuration, and the saved project checklist are preserved.
Later sessions are still attempted if one fails. Repeated kills succeed.

Takes no options or project filters. From a multiplexer pane it runs
independently, using the same shutdown log as `stop`.
