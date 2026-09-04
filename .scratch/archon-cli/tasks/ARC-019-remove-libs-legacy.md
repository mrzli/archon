# ARC-019: Remove the legacy libraries entry point

Status: completed

Area: Migration cleanup

Depends on: ARC-013, ARC-017

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Retire the old libraries script while preserving the independent library
repository's files.

## Acceptance checklist

- [x] `libs.mjs` is removed from the home overlay.
- [x] The dedicated CLI migration retains the exact previously managed destination script entry.
- [x] README, `AGENTS.md`, Git data, packages, and unrelated repository files are preserved.
- [x] The Archon libraries README documents `archon libs` as the replacement.

## Verification

- Test the dedicated migration in a temporary library repository fixture.
- Run the full libraries suite through `archon`.
- Run setup syntax checks and `git diff --check`.

Verified with the repeat-safe migration fixture, the complete remaining Archon
CLI test suite, `bash -n`, the libraries module syntax check, and
`git diff --check`. ShellCheck was unavailable.
