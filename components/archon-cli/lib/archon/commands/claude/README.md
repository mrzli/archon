# Claude

```bash
arc claude restart
```

Stops every Claude Code session running in a Herdr or tmux pane and resumes
each one's own conversation (`claude --resume <session-id>`) in the same pane
and directory. A session with no saved conversation yet starts fresh. There is
no selection or confirmation.

Run it from a separate shell with the sessions idle; unsent drafts are lost.
Common session options such as model, effort, permission mode, added
directories and settings are kept; prompts and one-off environment overrides
are not. If any session uses an unsupported option, such as `--worktree` or
`--print`, nothing is stopped.

Each session gets a few seconds to exit cleanly before it is killed. The
command returns once the launch commands are sent; startup errors appear in the
panes. Ctrl+C cancels it cleanly.

Discovery covers running Herdr sessions and tmux servers under
`${TMUX_TMPDIR:-/tmp}/tmux-$UID`, plus the calling shell's tmux server.
Standalone terminals and other tmux socket locations are not supported.
