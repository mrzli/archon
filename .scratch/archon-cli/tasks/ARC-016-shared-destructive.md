# ARC-016: Extract shared destructive workflows

Status: completed

Area: Shared code

Depends on: ARC-015

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Share equivalent delete and prune mechanics while retaining tool-specific
inventory and policy.

## Acceptance checklist

- [x] Equivalent argument parsing, cleanliness checks, confirmations, and removal orchestration are shared.
- [x] Root safety remains exact and tool-specific.
- [x] Remote inventory acquisition and blacklist policy remain tool-specific.
- [x] No destructive verification touches real project roots.

## Verification

- Test refusal cases, clean and unclean confirmations, dry-runs, inventory
  revalidation, and exit statuses in controlled fixtures.
- Run Node syntax checks and `git diff --check`.

Completed with isolated tests for invalid arguments, unsafe roots,
non-interactive refusal, clean and unclean confirmations, dry-runs, inventory
revalidation, and partial removal failures. Legacy/new parity and all focused
regressions, Node syntax checks, and `git diff --check` pass.
