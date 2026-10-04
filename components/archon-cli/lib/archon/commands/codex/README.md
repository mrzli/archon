# Codex

```bash
arc codex restart
```

Stops all detected Codex CLI processes together and sends `codex resume --last` in the
same project directory and terminal pane. No selection or confirmation.
The latest conversation for each directory is selected, which may differ from
the conversation previously open there.

Run from a separate shell after leaving Codex idle. Unsent drafts are discarded.
Other panes and applications stay running. Ctrl+C cancels the restart command
cleanly. The command returns after sending the launch commands, without waiting for
Codex to load or checking startup success. Any startup errors appear in the
individual panes. Slow-to-exit Codex processes are forcibly killed after a short
shared grace period.

Requires Codex launched from a shell in Herdr or tmux. Bare `arc codex` shows
usage. Original model, profile, directory and sandbox flags are retained;
prompts and images are not replayed. Unsupported flags, including `--worktree`,
cause a failure before closing that instance. One-off environment overrides
are not reproduced. The shared Codex daemon stays running.

Discovery covers running named Herdr sessions and tmux sockets under
`${TMUX_TMPDIR:-/tmp}/tmux-$UID`, plus the calling shell's `TMUX` socket.
Sockets left behind by stopped tmux servers are ignored.
Standalone terminals and other custom tmux socket locations are not supported.
