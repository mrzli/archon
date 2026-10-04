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

Session names use the project folder name, with `.` and `:` replaced by `-`
because tmux reserves those characters. tmux requires unique session names.
Start reports conflicting project names and refuses to reuse another project's
session. Stop or kill existing sessions before starting to replace older,
prefixed session names.

Interactive starts outside tmux attach in the current terminal and focus the
first selected project. Inside tmux, the current view is preserved.
Stop never attaches or prompts.

Stop from a tmux pane runs independently so closing that pane does not
interrupt the remaining work. Shutdown diagnostics are saved in
`${XDG_STATE_HOME:-~/.local/state}/archon/workspaces-tmux-stop.log`.

Stop closes all sessions tagged as Archon-managed on the current tmux server,
including projects no longer selected or present on disk. Untagged sessions are
preserved, even when their names resemble Archon sessions. Sessions created by
earlier versions without management tags are also preserved. Stopping an absent
server succeeds.

## Kill

```bash
arc w t kill
```

Stops the **entire current tmux server**, including sessions opened outside
Archon. Other tmux servers are unaffected. Running it when the server is already
stopped succeeds.

Takes no options or project filters. From a multiplexer pane it runs
independently, using the same shutdown log as `stop`.
