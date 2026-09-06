# ACTS-005: Convert projects command and tests

Status: planned

Depends on: ACTS-004

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Type project inventory and repository workflows without changing behavior.

## Scope

src/commands/projects and its focused/CLI tests, including relevant cases in mixed command suites.

## Acceptance checklist

- [ ] Convert project modules and their tests to TypeScript using the shared contracts.
- [ ] Type inventory records, options, and injected operations; narrow external values with existing validation.
- [ ] Preserve pagination, filtering/exclusions, fixed roots, missing-root behavior, subprocess arguments, and shared workflow semantics.
- [ ] Preserve confirmation, cleanliness, deletion, and remote-state safeguards.
- [ ] Update imports and remove only replaced JavaScript files; retain working workspace and CLI callers.

## Verification

Run inventory, missing-root, project CLI and exit-status tests plus applicable sync/destructive coverage, followed by the shared checkpoint checks.

## Completion record

Not started. Record changes, commands/results, compatibility findings, and any
remaining limitations here when completing the task.
