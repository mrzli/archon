# Backlog

Potential work, not yet agreed. When an item is taken up, items that change
another repository go there as a handoff.

## 1. Protection against package supply-chain attacks

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

## 3. Project skill for syncing Archon after an Omarchy update

Added 2026-11-05, during the Omarchy 4.5 adaptation. Create it after that
adaptation is finished, using the adaptation as the worked example. Its design
is still to be discussed.

The skill lists what should change in Archon, and the user makes the final
decision on most items. Which items, if any, it may apply on its own is open.
It must work in both Claude Code and Codex: put it in this repository and link
it into `.claude/skills` and `.agents/skills`, as the non-`--user` mode of the
skills repository's `scripts/sync-skills.sh` does.

Where a change belongs:

- Setup: the desired state starting from a clean install of the current
  Omarchy version, repeat-safe on later runs. Something a normal install ships
  and the user does not want belongs here, even though it is a removal. Example:
  every new Omarchy 4.5 install ships Superwhisper, so setup removes it.
- `migrations/`: only the gap from a previous state that will never exist again,
  such as an older Omarchy version or a superseded Archon configuration. Setup
  must not carry this code. A file that setup overwrites needs no migration.

What to check:

- Release notes and the changed defaults: key bindings, preinstalled packages,
  default applications, and Omarchy's installers and commands. Prefer defaults,
  and keep a personal binding only where a default does not work.
- Setup steps that install something Omarchy now provides. Example: Omarchy 4.5
  declares `claude` and `codex` in its own mise configuration.
- New-install behavior that differs from upgrades, because upgrades preserve old
  choices. Example: an upgrade keeps Voxtype and the old background, while a new
  install selects Superwhisper and Liftoff, so setup must not rely on the state
  of the upgraded machine.
- Interactions between personal configuration and new defaults. Example: the
  `grp:alts_toggle` layout switch collides with holding Right Alt for dictation.
- Archon code that uses Omarchy or Hyprland behavior that changed. Example:
  workspace numbers became per monitor.
- The installation guide and other documentation.
- Workarounds in Archon, and whether each is still needed.
- Backlog items that the update resolves.
- Applications on this machine that are not in Omarchy's package lists or
  Archon's setup, so a new install would not have them. The user either keeps
  one, which adds it to setup, or drops it, which adds a migration. Example: on
  Omarchy 4.5, the system `rust` package, Kdenlive, OBS Studio, Signal,
  Xournal++, and .NET runtime 9.0 went into a migration.
- Each Omarchy migration since the last check, listed as run here, not needed
  here, or needing a counterpart in setup or `migrations/`. It may still matter
  on another machine. Omarchy records the migrations it ran in
  `~/.local/state/omarchy/migrations/`. Example: Omarchy migration 1793477875
  appended old dictation keys to the live `bindings.lua`, which setup then
  overwrites.

## 4. Review installed applications periodically

Added 2026-11-05. From time to time, check for applications the user may not
need, and add the unwanted ones to setup's removal list. Sizes below are for
each package alone, on Omarchy 4.5. These applications cost disk space only
while they are not open.

Candidates that Omarchy installs and that were kept for now:

- LibreOffice, office suite, 423 MiB.
- Pinta, image editor, which depends on the .NET runtime, 74 MiB.
- LocalSend, file sharing between nearby devices, 67 MiB.
- Cliamp, terminal music player, 39 MiB.

## 5. Diagnose the workspace bar on the desktop's second monitor

Added 2026-11-05, after Archon moved to Omarchy 4.5. Investigate on the desktop,
which has two monitors. The laptop was checked with only its panel connected.

Reported on the desktop after the 4.5 update:

- The bars on both monitors show all 10 workspaces. Omarchy's bar should show
  1-5 plus any in use, and Archon no longer has its rule that keeps 1-10.
- On the right monitor, all 10 are grayed out, although workspace 1 there has a
  window. The left monitor marks its occupied workspaces correctly.

Unverified ideas from reading Omarchy's
`shell/plugins/bar/widgets/Workspaces.qml`, which dims a workspace number when
the workspace with that id has no windows and the monitor is not showing it:

- The running session or `~/.config/hypr/monitors.lua` still has the old rule,
  for example because setup or a new login has not happened since the change.
  This would explain the 10 numbers, but not the graying.
- The right bar's block in `~/.local/state/omarchy/monitor-workspaces` differs
  from the block of the workspaces that monitor shows, so the bar reads the
  wrong ids. All 10 grayed out points here, because the workspace the monitor
  shows is then not among the numbers the bar lists.

First log out and back in, and check whether the problem remains. If it does,
collect this:

```bash
grep -n 'persistent' ~/.config/hypr/monitors.lua
cat ~/.local/state/omarchy/monitor-workspaces
hyprctl workspacerules -j | jq -c '.[] | select(.persistent) | .workspaceString'
hyprctl workspaces -j | jq -r '.[] | "\(.id) \(.monitor) windows=\(.windows)"'
hyprctl monitors -j | jq -r '.[] | "\(.name) \(.description) active=\(.activeWorkspace.id)"'
```

If this turns out to be an Omarchy bug, report it upstream. See the Omarchy
agent skill's contributing guide.
