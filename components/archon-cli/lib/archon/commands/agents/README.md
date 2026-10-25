# Agents

```bash
arc agents restart
arc agents reload

# Short form
arc g restart
arc g reload
```

`restart` restarts every Claude Code session and then every Codex CLI session
running in a Herdr or tmux pane. Both agents are always handled; an agent with
no running sessions just reports that. A failed Claude restart does not prevent
the Codex restart, but the command then exits with status `1`.

`reload` runs `archon setup`, then `archon agents restart` in a new process so
the restart uses the CLI that setup just installed. Use it after changing
Archon or the skills repository, so running sessions pick up the new skills,
agent instructions, and settings. If setup fails, no session is restarted.

There is no selection or confirmation. Run it from a separate shell with the
sessions idle; unsent drafts are lost. Each session gets a few seconds to exit
cleanly before it is killed. The command returns once the launch commands are
sent; startup errors appear in the panes. Ctrl+C cancels it cleanly.

## Claude

Each Claude session resumes its own conversation (`claude --resume
<session-id>`) in the same pane and directory. A session with no saved
conversation yet starts fresh. Common session options such as model, effort,
permission mode, added directories and settings are kept; prompts and one-off
environment overrides are not. If any session uses an unsupported option, such
as `--worktree` or `--print`, no Claude session is stopped.

## Codex

Each Codex session runs `codex resume --last` in the same pane and directory.
This resumes the latest conversation in each directory, which may differ from
the one previously open there. Model, profile, directory and sandbox options are
kept; prompts, images and one-off environment overrides are not. If any session
uses an unsupported option, such as `--worktree`, no Codex session is stopped.
The shared Codex daemon keeps running.

## Discovery

Discovery covers running Herdr sessions and tmux servers under
`${TMUX_TMPDIR:-/tmp}/tmux-$UID`, plus the calling shell's tmux server.
Standalone terminals and other tmux socket locations are not supported.
