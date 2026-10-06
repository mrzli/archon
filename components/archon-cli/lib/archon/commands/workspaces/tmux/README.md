# tmux workspaces command

```bash
archon workspaces tmux start
archon workspaces tmux start --ai codex
archon workspaces tmux stop
archon workspaces tmux kill
archon workspaces tmux --help
```

Start chooses projects using the [shared project checklist](../README.md) and
gives each one a session named after the project folder, with `.` and `:`
replaced by `-`. tmux requires unique names, so start reports projects whose
names conflict and refuses to reuse another project's session. Repeated starts
preserve existing sessions. Failed creations roll back their new resources, and
later projects are still attempted.

Interactive starts outside tmux attach in the current terminal and focus the
first selected project. Inside tmux, the current view is preserved.

## Stop

Stop closes every Archon-managed session on the current tmux server, including
projects no longer selected or present on disk. Other sessions are preserved,
even when their names look like Archon's. Stopping an absent server succeeds.
From a tmux pane it runs independently, so closing that pane does not interrupt
it. Its log is `${XDG_STATE_HOME:-~/.local/state}/archon/workspaces-tmux-stop.log`.

## Kill

Stops the **entire current tmux server**, including sessions opened outside
Archon. Other tmux servers are unaffected, and killing a stopped server
succeeds. From a tmux pane it runs independently and uses the stop log.
