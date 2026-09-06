# ACTS-003: Convert shared modules and test helpers

Status: completed

Completed: 2026-09-06

Depends on: ACTS-002

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Establish typed shared contracts for the command batches.

## Scope

src/shared, focused shared tests, and tests/test-helpers plus common fixture helpers.

## Acceptance checklist

- [x] Convert remaining shared modules and their focused tests to TypeScript.
- [x] Type options, repository records, results, and injected operations at existing boundaries; keep types close to consumers.
- [x] Convert shared test helpers and ensure fake operations satisfy production contracts without fallback effects.
- [x] Preserve environment restoration, argument arrays, error/status semantics, destructive safeguards, and sync behavior.
- [x] Use inference and unknown narrowing; avoid blanket any, suppressions, and unrelated restructuring.
- [x] Update imports and barrels while keeping unconverted command groups working.

## Verification

Run focused shared, status, synchronization, destructive-operation, and fixture-dependent tests, then the shared checkpoint checks. Verify converted helpers do not silently permit real external operations.

## Completion record

ACTS-002 was committed as `82d06b9` before starting this checkpoint. ACTS-003
is implemented in the working tree, ready for the next implementation commit.

All remaining src/shared modules and their barrel now use TypeScript. Added
structural repository types, a success/error inspection-result union, working-tree
change records, typed status/deletion/pruning options, sync results/options, and
process overloads preserving text versus buffer results. Types live with their
consuming modules; command groups remain JavaScript with updated imports.

Shared test helpers and the destructive, synchronization, status, and root-context
suites now use TypeScript. Fakes are contextually checked against real operation
contracts. Confirmation fixtures use PassThrough streams with explicit isTTY
properties; local sync fixtures include required paths and retain injected
operations. The unclean-status fixture now includes its branch. The previously
converted alias test specifies tuple shape for typed runArchon arguments.

Preserved command arguments, output, statuses, Git/environment isolation,
confirmation/cleanup behavior, and all existing assertions. Sync operations now
capture their own correctly typed repository in a zero-argument callback, avoiding
an unsafe cast between local and remote repository shapes. The clone callback is
captured separately to preserve its original unbound invocation. No replacement
silently falls back to an external operation.

Caught filesystem errors are narrowed from unknown before reading code. The only
non-null assertion in shared source is a documented Map lookup: every successful
status is inserted before formatting. No any annotations, type suppressions,
new package dependencies, or compiler-policy changes were introduced.

Verification:

- `bun run --cwd components/archon-cli typecheck` passed with strict settings.
- `bash tests/archon-cli/run.sh < /dev/null` passed.
- The complete root runner with terminal stdin also passed.
- Both modes ran 129 tests across 18 files, five workspace cases, and three
  build/install cases, including local Git updates/status, destructive safeguards,
  terminal attachment, type-error failure, repeatable emission, aliases, and
  unrelated-file preservation in temporary homes.
- Source imports and installed emitted JavaScript both worked. No runtime helper
  tests were duplicated or removed.
- Bun parsing, Bash syntax, and whitespace checks passed. ShellCheck was
  unavailable. Full workstation setup was not executed.

ACTS-004 (libraries) is next. The three-day dependency release-age policy and
existing lockfile remain unchanged.
