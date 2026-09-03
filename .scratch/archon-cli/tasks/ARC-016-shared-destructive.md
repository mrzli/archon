# ARC-016: Extract shared destructive workflows

Status: proposed

Area: Shared code

Depends on: ARC-015

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Share equivalent delete and prune mechanics while retaining tool-specific
inventory and policy.

## Acceptance checklist

- [ ] Equivalent argument parsing, cleanliness checks, confirmations, and removal orchestration are shared.
- [ ] Root safety remains exact and tool-specific.
- [ ] Remote inventory acquisition and blacklist policy remain tool-specific.
- [ ] No destructive verification touches real project roots.

## Verification

- Test refusal cases, clean and unclean confirmations, dry-runs, inventory
  revalidation, and exit statuses in controlled fixtures.
- Run Node syntax checks and `git diff --check`.
