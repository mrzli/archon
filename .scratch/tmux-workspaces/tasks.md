# Tmux Workspace Restructuring Tasks

Source: [spec.md](./spec.md)

Status: completed and archived

Completed: 2026-09-03

This index and its task files are retained as the archived implementation and
verification record. Enduring operational instructions are in the root README.

Each file below is an independently actionable implementation, migration,
verification, documentation, or completion task. Small requirements remain as
acceptance checklists within the task that owns them.

## Success criteria

- The managed workspace launcher directory contains only `all.sh`,
  `hubs.sh`, `flashcards.sh`, `jslibs.sh`, and `misc-projects.sh`.
- Every script accepts exactly one `start` or `stop` action.
- Repeating either action is safe and does not duplicate tmux state.
- Missing project directories are reported and skipped without preventing work
  on other configured projects.
- Real group failures are returned to `all.sh`; aggregate start does not attach
  or switch clients after any group fails.
- The relevant syntax, lint, behavior, and repository checks pass.

## Task index (16)

### Interface

- [x] [TMW-001: Define the launcher command contract](./tasks/TMW-001-command-contract.md)

### Group launchers

- [x] [TMW-002: Implement `hubs.sh`](./tasks/TMW-002-hubs-script.md)
- [x] [TMW-003: Implement `flashcards.sh`](./tasks/TMW-003-flashcards-script.md)
- [x] [TMW-004: Implement `jslibs.sh`](./tasks/TMW-004-jslibs-script.md)
- [x] [TMW-005: Implement `misc-projects.sh`](./tasks/TMW-005-misc-projects-script.md)

### Aggregate launcher

- [x] [TMW-006: Implement `all.sh`](./tasks/TMW-006-aggregate-script.md)

### Migration

- [x] [TMW-007: Remove the replaced launcher files](./tasks/TMW-007-remove-legacy-launchers.md)

### Verification

- [x] [TMW-008: Run static and command-interface validation](./tasks/TMW-008-static-validation.md)
- [x] [TMW-009: Prepare isolated tmux behavior verification](./tasks/TMW-009-safe-verification-environment.md)
- [x] [TMW-010: Verify hub launcher behavior](./tasks/TMW-010-verify-hubs.md)
- [x] [TMW-011: Verify flashcards launcher behavior](./tasks/TMW-011-verify-flashcards.md)
- [x] [TMW-012: Verify JavaScript-library launcher behavior](./tasks/TMW-012-verify-jslibs.md)
- [x] [TMW-013: Verify miscellaneous-project launcher behavior](./tasks/TMW-013-verify-misc-projects.md)
- [x] [TMW-014: Verify aggregate launcher behavior](./tasks/TMW-014-verify-aggregate.md)

### Documentation

- [x] [TMW-015: Document the completed launcher structure](./tasks/TMW-015-durable-documentation.md)

### Completion

- [x] [TMW-016: Review and close the restructuring spec](./tasks/TMW-016-close-spec.md)
