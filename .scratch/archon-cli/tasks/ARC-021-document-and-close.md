# ARC-021: Complete documentation and close the proposal

Status: completed

Area: Documentation

Depends on: ARC-018, ARC-019, ARC-020

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Make durable documentation describe the final installed behavior and archive
the completed planning records.

## Acceptance checklist

- [x] Archon's tool-local READMEs document the CLI, alias, and command collections.
- [x] The repository root README remains focused on workstation setup.
- [x] Obsolete launcher instructions are removed from durable documentation.
- [x] The dedicated migration verifies the replacement CLI before cleanup.
- [x] Installed help and tool-local README usage agree.
- [x] The specification and task records contain final verification evidence.
- [x] The specification and task index are marked completed and archived in place.

## Verification

- Run the full focused CLI suite and all Node syntax checks.
- Run `bash -n` and ShellCheck when available on setup, migration, and test scripts.
- Run the dedicated migration suite.
- Run `git diff --check`.

The final audit passed on 2026-09-04. All executable and module syntax checks
passed, all 15 shell-suite checks and 29 Node tests passed, and the migration
was verified repeat-safe against a temporary home. `git diff --check` passed.
ShellCheck was unavailable. Tasks ARC-001 through ARC-020 were complete before
this proposal was archived.
