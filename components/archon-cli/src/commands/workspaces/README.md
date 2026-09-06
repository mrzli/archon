# Workspaces command

Manage tmux workspace sessions through the Archon CLI:

```bash
archon workspaces start
archon workspaces stop
archon workspaces start --group general
archon workspaces stop -g jslibs
archon workspaces kill
```

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
