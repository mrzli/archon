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

## 2. Protection against package supply-chain attacks

Added 2026-10-30. Prompted by the September 2025 npm attacks (the hijacked
`chalk` and `debug` releases and the Shai-Hulud worm), where malicious versions
were installed within hours of publication and ran through install scripts.

Options discussed:

- Release-age cooldown (recommended): package managers refuse versions younger
  than a set age, such as one day. Declarative, so it fits `data/home/`. npm
  `min-release-age` in `~/.npmrc` (npm 11.10+), pnpm `minimumReleaseAge`
  (minutes; one day by default in pnpm 11), Bun `minimumReleaseAge` in
  `bunfig.toml` (seconds), Yarn `npmMinimalAgeGate`.
- Block install scripts by default (recommended): npm `ignore-scripts=true`;
  pnpm already blocks them unless allowed. Packages with native builds then
  need an explicit allow.
- Socket Firewall (`sfw`): a free wrapper that blocks packages Socket has
  confirmed malicious. Not open source, collects anonymous telemetry, and
  proxies installs; it adds little over a cooldown.
- Keep publish and access tokens out of plain files and environment variables,
  which Shai-Hulud stole to spread.

Open points:

- Find which package managers and versions are in use, to choose the settings.
- The versions and units above come from blogs and vendor pages; verify them
  against each tool's documentation before relying on them.
