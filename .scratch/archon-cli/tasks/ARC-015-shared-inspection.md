# ARC-015: Extract shared repository inspection behavior

Status: completed

Area: Shared code

Depends on: ARC-014

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Remove duplicated local repository discovery and status inspection without
combining unlike tool policy.

## Acceptance checklist

- [x] Equivalent Git discovery and inspection behavior is shared.
- [x] Root layouts, blacklists, remote inventories, and package logic remain local.
- [x] Projects and libraries output remains unchanged.

## Verification

- Compare fixture inventories, status details, warnings, formatting, and errors
  before and after extraction.
- Run Node syntax checks and `git diff --check`.

Completed with legacy/new parity fixtures covering discovery, clean and
modified repositories, stashes, ahead branches, fetch warnings, malformed
repositories, and formatted output. All focused regressions, Node syntax
checks, and `git diff --check` pass.
