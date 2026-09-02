# Tmux Workspace Restructuring Tasks

Source: [spec.md](./spec.md)

Status: not started

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

- [ ] [TMW-001: Define the launcher command contract](./tasks/TMW-001-command-contract.md)

### Group launchers

- [ ] [TMW-002: Implement `hubs.sh`](./tasks/TMW-002-hubs-script.md)
- [ ] [TMW-003: Implement `flashcards.sh`](./tasks/TMW-003-flashcards-script.md)
- [ ] [TMW-004: Implement `jslibs.sh`](./tasks/TMW-004-jslibs-script.md)
- [ ] [TMW-005: Implement `misc-projects.sh`](./tasks/TMW-005-misc-projects-script.md)

### Aggregate launcher

- [ ] [TMW-006: Implement `all.sh`](./tasks/TMW-006-aggregate-script.md)

### Migration

- [ ] [TMW-007: Remove the replaced launcher files](./tasks/TMW-007-remove-legacy-launchers.md)

### Verification

- [ ] [TMW-008: Run static and command-interface validation](./tasks/TMW-008-static-validation.md)
- [ ] [TMW-009: Prepare isolated tmux behavior verification](./tasks/TMW-009-safe-verification-environment.md)
- [ ] [TMW-010: Verify hub launcher behavior](./tasks/TMW-010-verify-hubs.md)
- [ ] [TMW-011: Verify flashcards launcher behavior](./tasks/TMW-011-verify-flashcards.md)
- [ ] [TMW-012: Verify JavaScript-library launcher behavior](./tasks/TMW-012-verify-jslibs.md)
- [ ] [TMW-013: Verify miscellaneous-project launcher behavior](./tasks/TMW-013-verify-misc-projects.md)
- [ ] [TMW-014: Verify aggregate launcher behavior](./tasks/TMW-014-verify-aggregate.md)

### Documentation

- [ ] [TMW-015: Document the completed launcher structure](./tasks/TMW-015-durable-documentation.md)

### Completion

- [ ] [TMW-016: Review and close the restructuring spec](./tasks/TMW-016-close-spec.md)
