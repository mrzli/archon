# ARC-015: Extract shared repository inspection behavior

Status: proposed

Area: Shared code

Depends on: ARC-014

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Remove duplicated local repository discovery and status inspection without
combining unlike tool policy.

## Acceptance checklist

- [ ] Equivalent Git discovery and inspection behavior is shared.
- [ ] Root layouts, blacklists, remote inventories, and package logic remain local.
- [ ] Projects and libraries output remains unchanged.

## Verification

- Compare fixture inventories, status details, warnings, formatting, and errors
  before and after extraction.
- Run Node syntax checks and `git diff --check`.
