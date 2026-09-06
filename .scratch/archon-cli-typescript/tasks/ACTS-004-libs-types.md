# ACTS-004: Convert libraries command and tests

Status: planned

Depends on: ACTS-003

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Type library inventory, dependency ordering, and command behavior.

## Scope

src/commands/libs and its focused/CLI tests, including relevant cases in mixed command suites.

## Acceptance checklist

- [ ] Convert library modules and their tests to TypeScript using the shared contracts.
- [ ] Type package records, dependency graphs, build results, command options, and injected operations.
- [ ] Narrow manifest and GitHub inventory data using existing accepted-input and failure behavior.
- [ ] Preserve cycle detection, dependency-first ordering, install/build subprocess arguments, fixed roots, and destructive safeguards.
- [ ] Update imports and remove only JavaScript files replaced in this batch. Track remaining library cases in mixed suites for the final audit.

## Verification

Run inventory, build ordering/cycle, missing-root, CLI, and library exit-status coverage, followed by the shared checkpoint checks.

## Completion record

Not started. Record changes, commands/results, compatibility findings, and any
remaining limitations here when completing the task.
