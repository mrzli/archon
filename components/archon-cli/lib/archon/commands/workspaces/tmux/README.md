# tmux workspaces command

```bash
archon workspaces tmux start
archon workspaces tmux start --ai claude
archon workspaces tmux stop
archon workspaces tmux --help
```

Start chooses projects using the [shared project checklist](../README.md).
Each project has Neovim, an AI tool, and a shell. `--ai codex` is the default
and runs `codex resume --last`; `--ai claude` runs `claude --continue`.
The tool must be on `PATH`. The option affects newly created workspaces.
Repeated starts preserve existing workspaces. Failed creations roll back their
new resources and later projects are still attempted.

Interactive starts outside tmux attach in the current terminal and focus the
first selected project. Inside tmux, the current view is preserved.
Stop never attaches or prompts, and stops all discovered project workspaces.

Stop from a tmux pane runs independently so closing that pane does not
interrupt the remaining work. Shutdown diagnostics are saved in
`${XDG_STATE_HOME:-~/.local/state}/archon/workspaces-tmux-stop.log`.

`kill` stops the entire tmux server, including unrelated sessions.
