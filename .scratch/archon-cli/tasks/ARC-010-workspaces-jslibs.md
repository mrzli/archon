# ARC-010: Convert the jslibs workspace group

Status: completed

Area: Workspaces

Depends on: ARC-009

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Route dynamically discovered JavaScript-library sessions to JavaScript while
remaining groups continue to work.

## Acceptance checklist

- [x] Immediate Git repository discovery matches the legacy launcher.
- [x] Session naming and start/stop behavior match the legacy launcher.
- [x] Existing shared workspace primitives are reused where appropriate.
- [x] Miscellaneous projects and hubs remain delegated to Bash.

## Verification

- Verify discovery, missing root, repeated start/stop, session filtering, and
  tmux list failures with controlled fixtures.
- Run Node syntax checks and `git diff --check`.

Completed with dedicated Node tests, the workspace adapter and legacy launcher
regression suites, repository-level CLI and installation tests, Node syntax
checks, and `git diff --check`.
