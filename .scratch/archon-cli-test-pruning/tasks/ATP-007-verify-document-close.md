# ATP-007: Verify the reduction and archive the plan

Status: completed

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Scope

`components/archon-cli/tests/README.md` and this planning directory.

Production changes and new tests are prohibited.

## Acceptance checklist

- [x] Confirm that each code change deletes or simplifies existing tests and that no production file changed.
- [x] Confirm no test cases, new coverage scenarios, test files, frameworks, or replacement abstractions were added.
- [x] Run the existing complete verification entry point with terminal and non-terminal stdin; do not create additional verification tests.
- [x] Check changed test modules with the existing Node syntax checks, changed shell tests with Bash syntax checks, and ShellCheck when available.
- [x] Run whitespace checks, including staged changes if present.
- [x] Record actual test and line-count reductions without setting a quota or treating fewer tests as proof of correctness.
- [x] Keep durable test documentation accurate, including intentionally reduced coverage.
- [x] Only after completion, mark these tasks and the spec completed and archived.

## Verification

- Run `tests/archon-cli/run.sh` and audit the final path list and diff.
- Review the diff for test-only changes and no added cases.
- Run `git diff --check`.

## Coverage decision

Retain existing consequential coverage: deletion safeguards, rollback, convergence, dependency ordering/cycles, and actual terminal attachment.

Completed: 2026-09-06. Against baseline `a9dee70`, test code has 363 fewer lines
(23 added within simplified existing assertions, 386 removed). Node cases fell
from 140 to 126; shell integration cases fell from 10 to 8. All remaining cases
passed with terminal and non-terminal stdin, including Node and individual Bash
syntax checks. ShellCheck was unavailable. Final path/diff review confirmed no
production changes, new tests, new fixtures, or framework additions. Test
README and task records describe the intentionally reduced coverage.
