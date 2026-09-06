# ACTS-006: Convert workspaces command and tests

Status: completed

Completed: 2026-09-06

Depends on: ACTS-005

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Type workspace definitions and tmux operations while preserving lifecycle behavior.

## Scope

src/commands/workspaces, TypeScript workspace tests, and only necessary invocation/path updates in Bash integration tests.

## Acceptance checklist

- [x] Convert workspace modules and focused tests to TypeScript.
- [x] Type group definitions, tmux operations, options, and fake objects against the real contracts.
- [x] Preserve group selection/order, repeat-safe start/stop, rollback, missing-directory handling, and failure propagation.
- [x] Preserve terminal/nonterminal behavior and behavior inside tmux.
- [x] Keep the adapter and fake tmux executable in Bash; retain their isolation and subprocess integration coverage.

## Verification

Run all focused workspace tests and the five existing adapter scenarios through the built JavaScript CLI, followed by the shared checkpoint checks.

## Completion record

ACTS-005 was committed as `7516131` before starting this checkpoint. ACTS-006
is implemented in the working tree, ready for the next implementation commit.

Converted all eight workspace runtime modules and all six focused test suites
to TypeScript. Added shared action/context types, shell/editor session definitions,
tmux operation and subprocess contracts, group names/handlers, and a discriminated
argument-parser result. Group contexts require only the tmux operations they use;
the command boundary still creates production dependencies. Filesystem errors are
narrowed from unknown without changing ENOENT handling.

Fixture options, session sets, operation logs, and scenario tuples are typed.
Group fakes satisfy the corresponding handler context, and the orchestrator's
complete tmux fake throws for unexpected operations. No injected operation falls
back to the workstation. Existing assertions and scenarios remain intact.
Updated the command barrel import and installed workspace module assertion to
the emitted JavaScript path. The Bash adapter and fake tmux are unchanged.

Verification:

- Strict typecheck and checked JavaScript build passed.
- `bash tests/archon-cli/run.sh < /dev/null` and the same runner with terminal
  stdin passed: 129 tests across 18 files, five workspace adapter cases, and
  three build/install cases per run.
- Coverage retains fixed definitions/commands, group selection and aggregate
  ordering, repeated starts/stops, missing directories, repository discovery,
  rollback/retry/cleanup errors, continued processing after failures, injected
  dependencies, exact attachment, and terminal/nonterminal/inside-tmux behavior.
- Compilation-error gates, stale-output removal, copied installation, both
  executable aliases, repeated overlay copy, and unrelated-file preservation passed.
- Bash syntax, Bun parsing, and whitespace checks passed. ShellCheck was
  unavailable. No full setup or real session/home mutation was performed.

No dependencies, age-policy changes, type suppressions, or any annotations were
introduced. ACTS-007 (final conversion and deployment verification) is next.
