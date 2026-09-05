# ATP-007: Verify the reduction and archive the plan

Status: pending

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Scope

`components/archon-cli/tests/README.md` and this planning directory.

Production changes and new tests are prohibited.

## Acceptance checklist

- [ ] Confirm that each code change deletes or simplifies existing tests and that no production file changed.
- [ ] Confirm no test cases, new coverage scenarios, test files, frameworks, or replacement abstractions were added.
- [ ] Run the existing complete verification entry point with terminal and non-terminal stdin; do not create additional verification tests.
- [ ] Check changed test modules with the existing Node syntax checks, changed shell tests with Bash syntax checks, and ShellCheck when available.
- [ ] Run whitespace checks, including staged changes if present.
- [ ] Record actual test and line-count reductions without setting a quota or treating fewer tests as proof of correctness.
- [ ] Keep durable test documentation accurate, including intentionally reduced coverage.
- [ ] Only after completion, mark these tasks and the spec completed and archived.

## Verification

- Run `tests/archon-cli/run.sh` and audit the final path list and diff.
- Review the diff for test-only changes and no added cases.
- Run `git diff --check`.

## Coverage decision

Retain existing consequential coverage: deletion safeguards, rollback, convergence, dependency ordering/cycles, and actual terminal attachment.
