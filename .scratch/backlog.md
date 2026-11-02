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

## 2. Adapt Archon to Omarchy 4.5

Added 2026-11-02. Omarchy 4.5 is in release candidates (4.5.0-rc3 on
2026-11-02; this machine runs 4.0.6). Wait for the final release, then
check after updating:

- The Hyprland key bindings in `data/home/.config/hypr/bindings.lua` still
  load and work, including bindings added since this item was written.
- Setup and the Archon scripts still work against the new release, such as
  the Omarchy commands and default paths they use.
- `intel-media-driver` is installed on Intel machines whose GPU `lspci`
  names only "[Intel Graphics]", such as the Arrow Lake laptop. Omarchy
  4.0.6 skips it there. omarchy#17150 fixes it on Omarchy's default branch
  (reported in omarchy#11958 and omarchy#13987), but 4.5.0-rc3 does not
  include the fix yet, so the final release may still skip it.
