# ARC-014: Extract shared low-level JavaScript utilities

Status: completed

Area: Shared code

Depends on: ARC-006, ARC-007

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Make projects and libraries importable and share only their equivalent
low-level mechanics.

## Acceptance checklist

- [x] Both tools expose `main(arguments, context)` without top-level execution on import.
- [x] The root CLI imports them instead of spawning child Node processes.
- [x] Process, Git invocation, path, and error-normalization utilities are shared.
- [x] Domain behavior and output remain unchanged.

## Verification

- Run parity checks through direct module harnesses and `archon`.
- Run Node syntax checks and `git diff --check`.

Completed with silent-import and direct-module parity coverage, the existing
legacy and root CLI contract suites, installation and workspace regressions,
Node syntax checks, and `git diff --check`.
