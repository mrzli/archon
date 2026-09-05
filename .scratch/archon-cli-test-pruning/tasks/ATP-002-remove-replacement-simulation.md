# ATP-002: Remove the simulated installation-replacement test

Status: completed

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Scope

`tests/archon-cli/test-install-layout.sh` and its description in the test README.

Production changes and new tests are prohibited.

## Acceptance checklist

- [x] Delete `test_managed_library_replacement_scope` and its runner registration.
- [x] Remove the replacement-list variable and any other helpers or variables made unused solely by that deletion.
- [x] Keep the existing repeated-installation case, executable and shortcut checks, runtime import coverage, filtering, and unrelated-file preservation assertions.
- [x] Update the test README to describe only the remaining layout coverage.
- [x] Do not extract installation logic or change setup, installation behavior, or managed-directory configuration.

## Verification

- Run the remaining installation-layout test.
- Review the diff for test-only changes and no added cases.
- Run `git diff --check`.

## Coverage decision

The test-driven simulation of replacement and its replacement-list membership assertions are intentionally removed; production replacement is not tested by this suite.

Completed: 2026-09-06. Removed the replacement simulation and its unused list
variable. The retained repeat-install layout case, Bash syntax, and whitespace
checks passed. No production files changed.
