# ARC-014: Extract shared low-level JavaScript utilities

Status: proposed

Area: Shared code

Depends on: ARC-006, ARC-007

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Make projects and libraries importable and share only their equivalent
low-level mechanics.

## Acceptance checklist

- [ ] Both tools expose `main(arguments, context)` without top-level execution on import.
- [ ] The root CLI imports them instead of spawning child Node processes.
- [ ] Process, Git invocation, path, and error-normalization utilities are shared.
- [ ] Domain behavior and output remain unchanged.

## Verification

- Run parity checks through direct module harnesses and `archon`.
- Run Node syntax checks and `git diff --check`.
