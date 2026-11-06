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

## 6. Intermittent Herdr restart integration test

Added 2026-11-06. The test "real Herdr restart from inside a pane reattaches
the terminal that started the workspaces", in
`components/archon-cli/tests/integration/herdr_test.rb`, sometimes fails with
"execution expired". It passed two of three runs on `master` and two of three
on the branch that reduced workspaces to a shell and an AI tool, so that change
is not the likely cause. The `master` failure was the wait for the terminal
process to exit, at `tests/workspace_helpers.rb:31`, which allows 10 seconds.

Open points:

- Find out whether the test or `arc w h restart` is at fault, because a slow or
  missed reattach would also affect real restarts.
- `bash tests/test.sh` does not run the integration tests, so this failure shows
  only when they are run by hand.
