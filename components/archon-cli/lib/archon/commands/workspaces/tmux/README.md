# Tmux workspaces command

Manage tmux workspace sessions through the Archon CLI:

```bash
archon workspaces tmux start
archon workspaces tmux stop
archon workspaces tmux start --group general
archon workspaces tmux start --group flashcards --ai claude
archon workspaces tmux stop -g jslibs
archon workspaces tmux kill
```

For `start`, use `--ai codex` (the default) or `--ai claude` to choose the AI
window. Codex runs `codex resume --last`; Claude Code runs `claude --continue`.
The selected tool must be available on `PATH`. The option applies only to newly
created sessions. Stop and start a group to change its AI tool. The `general`
group has only a shell and is unaffected.

`kill` takes no arguments or options and runs `tmux kill-server`, terminating
all sessions on the server, including sessions outside Archon's workspace groups.
It returns tmux's exit status.

Without `--group` or `-g`, the command runs every group in the listed order for
start and reverse order for stop. Every group is attempted after a failure.
After a successful start in an interactive terminal outside tmux, the command
attaches to an existing session from the requested group. Aggregate start
prefers `main`. It never creates an extra session for attachment. Inside tmux,
the current session stays selected. Stop, help, and non-interactive calls do
not attach.

Stop from a tmux pane runs independently so closing that pane does not interrupt
the remaining work. Shutdown output is saved in
`${XDG_STATE_HOME:-$HOME/.local/state}/archon/workspaces-tmux-stop.log`.
