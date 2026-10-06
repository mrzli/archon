# Codex

```bash
arc codex restart
```

Stops every Codex CLI session running in a Herdr or tmux pane and runs
`codex resume --last` in the same pane and directory. This resumes the latest
conversation in each directory, which may differ from the one previously open
there. There is no selection or confirmation.

Run it from a separate shell with the sessions idle; unsent drafts are lost.
Model, profile, directory and sandbox options are kept; prompts, images and
one-off environment overrides are not. If any session uses an unsupported
option, such as `--worktree`, nothing is stopped. The shared Codex daemon keeps
running.

Each session gets a few seconds to exit cleanly before it is killed. The
command returns once the launch commands are sent; startup errors appear in the
panes. Ctrl+C cancels it cleanly.

Discovery covers running Herdr sessions and tmux servers under
`${TMUX_TMPDIR:-/tmp}/tmux-$UID`, plus the calling shell's tmux server.
Standalone terminals and other tmux socket locations are not supported.
