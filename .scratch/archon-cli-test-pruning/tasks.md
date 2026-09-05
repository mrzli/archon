# Archon CLI test pruning tasks

Status: completed and archived

Completed: 2026-09-06

Source: [Specification](./spec.md)

All seven tasks are complete, one commit per task, on `test/prune-archon-cli`.
Production files are unchanged and no new tests were added. The earlier
reliability plan remains an archived record.

## [ATP-001: Remove tests of Git test helpers](./tasks/ATP-001-remove-helper-tests.md)

Dedicated regression coverage of the test environment helpers is intentionally dropped; their isolation behavior remains in use.

Verify: Run the existing component suite, including repository-status and sync-workflow tests.

## [ATP-002: Remove the simulated installation-replacement test](./tasks/ATP-002-remove-replacement-simulation.md)

The test-driven simulation of replacement and its replacement-list membership assertions are intentionally removed; production replacement is not tested by this suite.

Verify: Run the remaining installation-layout test.

## [ATP-003: Prune mock-only and redundant workspace checks](./tasks/ATP-003-simplify-workspace-adapter.md)

The direct test of the fake's rejection behavior is intentionally dropped. Actual CLI attachment and session-state checks remain.

Verify: Run the existing workspace adapter with terminal and non-terminal stdin.

## [ATP-004: Reduce duplicated workspace command transcripts](./tasks/ATP-004-reduce-workspace-transcripts.md)

Group tests stop independently repeating every shared window-creation step. Shared helper tests retain detailed command sequencing.

Verify: Run existing workspace module tests and the adapter.

## [ATP-005: Trim overlapping help and alias checks](./tasks/ATP-005-trim-help-overlap.md)

Some spelling/entry-point combinations cease to have standalone tests; the retained help and alias cases still establish success and forwarding.

Verify: Run the existing exit-status suite.

## [ATP-006: Remove the incidental parser-permissiveness test](./tasks/ATP-006-remove-incidental-parser-case.md)

Empty names and undefined flags are no longer pinned as a required contract by a dedicated test.

Verify: Run the existing library inventory tests.

## [ATP-007: Verify the reduction and archive the plan](./tasks/ATP-007-verify-document-close.md)

Retain existing consequential coverage: deletion safeguards, rollback, convergence, dependency ordering/cycles, and actual terminal attachment.

Verify: Run `tests/archon-cli/run.sh` and audit the final path list and diff.

## Done when

All intended pruning is complete, the remaining suite passes, production code
is unchanged, no tests were added, and actual reductions and accepted coverage
losses are documented.

## Final results

- Test code: 363 fewer lines net relative to `a9dee70`.
- Node tests: 140 → 126; shell integration cases: 10 → 8.
- Remaining full suite passed with terminal and non-terminal stdin.
- Node/Bash syntax and whitespace checks passed; ShellCheck was unavailable.
- No production changes, added tests, or new fixture abstractions.
