# Claude

```bash
arc claude restart
```

Stops all detected Claude Code processes together and resumes each one's
conversation with `claude --resume <session-id>` in the same project directory
and terminal pane. A session that has no saved conversation yet starts as a new
`claude` session. No selection or confirmation.

Run from a separate shell after leaving Claude idle. Unsent drafts are discarded.
Other panes and applications stay running. Ctrl+C cancels the restart command
cleanly. The command returns after sending the launch commands, without waiting for
Claude to load or checking startup success. Any startup errors appear in the
individual panes. Claude gets a few seconds to exit cleanly; processes still
running after that are forcibly killed.

Requires Claude launched from a shell in Herdr or tmux. Bare `arc claude` shows
usage. Original model, effort, permission mode, added directories, settings and
other common session options are retained; prompts are not replayed.
Unsupported options, including `--worktree` and `--print`, and processes without a
session record in `~/.claude/sessions` cause a failure before any session is
stopped. One-off environment overrides are not reproduced.

Discovery covers running named Herdr sessions and tmux sockets under
`${TMUX_TMPDIR:-/tmp}/tmux-$UID`, plus the calling shell's `TMUX` socket.
Sockets left behind by stopped tmux servers are ignored.
Standalone terminals and other custom tmux socket locations are not supported.
