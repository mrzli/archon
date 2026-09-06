# ACTS-003: Convert shared modules and test helpers

Status: planned

Depends on: ACTS-002

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Establish typed shared contracts for the command batches.

## Scope

src/shared, focused shared tests, and tests/test-helpers plus common fixture helpers.

## Acceptance checklist

- [ ] Convert remaining shared modules and their focused tests to TypeScript.
- [ ] Type options, repository records, results, and injected operations at existing boundaries; keep types close to consumers.
- [ ] Convert shared test helpers and ensure fake operations satisfy production contracts without fallback effects.
- [ ] Preserve environment restoration, argument arrays, error/status semantics, destructive safeguards, and sync behavior.
- [ ] Use inference and unknown narrowing; avoid blanket any, suppressions, and unrelated restructuring.
- [ ] Update imports and barrels while keeping unconverted command groups working.

## Verification

Run focused shared, status, synchronization, destructive-operation, and fixture-dependent tests, then the shared checkpoint checks. Verify converted helpers do not silently permit real external operations.

## Completion record

Not started. Record changes, commands/results, compatibility findings, and any
remaining limitations here when completing the task.
