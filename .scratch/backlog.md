# Backlog

Potential work, not yet agreed. When an item is taken up, items that change
another repository go there as a handoff.

## 1. Hierarchical names for spawned agent sessions

Added 2026-10-24. Belongs to the skills repository (`mrzli/skills`), where
`fork-tab`, `conclude`, and `join` are to become spawn, yield, and collect.

Spawn will be able to open a child from a child, so session names should show
the tree:

- Root sessions get a letter: `claude-A`, `claude-B`. Letters keep roots apart
  from children, so a second root cannot be mistaken for a child.
- Children add numbers: `claude-A-1`, `claude-A-2`, then `claude-A-1-1`.

Approach as discussed:

- Assign the root's letter lazily, when an unnamed session first runs spawn.
  This covers every way a session starts (typed `claude`, the workspace AI tab,
  resume) without changing how sessions launch.
- Keep a small registry per project directory: a locked state file that maps
  each letter to a session ID and the tab or pane it runs in.
- Reuse letters. Before allocating, drop entries whose tab no longer exists in
  herdr or tmux, then take the lowest free letter.
- Rename the parent's tab to its new name from the spawn script; herdr and
  `tmux rename-window` both support that.

Open points:

- Claude Code has no command-line way to rename a running session; only `-n`
  at launch. Renaming the root's session name would need either the user to run
  `/rename` once, or the script typing it into the parent's pane, which is
  fragile and untested. The tab label alone may be enough.
- A resumed old root whose letter was reused keeps its old name until its next
  spawn, which then gives it a fresh letter.
