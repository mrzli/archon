# ARC-017: Extract shared synchronization behavior

Status: proposed

Area: Shared code

Depends on: ARC-016

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Share equivalent repository clone and update orchestration without forcing
different domain behavior into one abstraction.

## Acceptance checklist

- [ ] Equivalent clone/update planning and execution are shared.
- [ ] GitHub inventory differences remain within each tool.
- [ ] Library build and dependency behavior remains library-specific.
- [ ] Output and failure behavior remain unchanged.

## Verification

- Compare controlled sync plans, successes, failures, and output for both tools.
- Run Node syntax checks and `git diff --check`.
