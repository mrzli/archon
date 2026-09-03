# ARC-017: Extract shared synchronization behavior

Status: completed

Area: Shared code

Depends on: ARC-016

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Share equivalent repository clone and update orchestration without forcing
different domain behavior into one abstraction.

## Acceptance checklist

- [x] Equivalent clone/update planning and execution are shared.
- [x] GitHub inventory differences remain within each tool.
- [x] Library build and dependency behavior remains library-specific.
- [x] Output and failure behavior remain unchanged.

## Verification

- Compare controlled sync plans, successes, failures, and output for both tools.
- Run Node syntax checks and `git diff --check`.

Verified with `tests/archon-cli/sync-workflow.test.mjs`, the complete Archon CLI
test suite, Node syntax checks, and `git diff --check`.
