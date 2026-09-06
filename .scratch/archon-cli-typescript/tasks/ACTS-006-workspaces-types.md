# ACTS-006: Convert workspaces command and tests

Status: planned

Depends on: ACTS-005

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Type workspace definitions and tmux operations while preserving lifecycle behavior.

## Scope

src/commands/workspaces, TypeScript workspace tests, and only necessary invocation/path updates in Bash integration tests.

## Acceptance checklist

- [ ] Convert workspace modules and focused tests to TypeScript.
- [ ] Type group definitions, tmux operations, options, and fake objects against the real contracts.
- [ ] Preserve group selection/order, repeat-safe start/stop, rollback, missing-directory handling, and failure propagation.
- [ ] Preserve terminal/nonterminal behavior and behavior inside tmux.
- [ ] Keep the adapter and fake tmux executable in Bash; retain their isolation and subprocess integration coverage.

## Verification

Run all focused workspace tests and the five existing adapter scenarios through the built JavaScript CLI, followed by the shared checkpoint checks.

## Completion record

Not started. Record changes, commands/results, compatibility findings, and any
remaining limitations here when completing the task.
