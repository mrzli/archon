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
Repeated starts preserve existing workspaces. Failed creations roll back their
new resources and later projects are still attempted.

Interactive starts outside Herdr attach in the current terminal and focus the
first selected project. Inside Herdr, the current view is preserved.
Stop never attaches or prompts, and stops all discovered project workspaces.

Stop from a Herdr pane runs independently so closing that pane does not
interrupt the remaining work. Shutdown diagnostics are saved in
`${XDG_STATE_HOME:-~/.local/state}/archon/workspaces-herdr-stop.log`.

Uses the dedicated Herdr session `archon`. It starts its background server when
needed. `kill` stops this entire session, including extra workspaces.
Server diagnostics are saved in `archon/workspaces-herdr-server.log` under the
state directory.
