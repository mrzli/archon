# ATP-001: Remove tests of Git test helpers

Status: completed

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Scope

`components/archon-cli/tests/git-environment.test.mjs` and its description in the test README.

Production changes and new tests are prohibited.

## Acceptance checklist

- [x] Delete the three tests in `git-environment.test.mjs` and the file itself.
- [x] Keep `createGitEnvironment`, `withGitFixture`, and their production-workflow test callers unchanged.
- [x] Remove the README claim that the suite reruns Git workflows under synthetic conflicting settings.
- [x] Do not introduce replacement helper tests or new fixture machinery.

## Verification

- Run the existing component suite, including repository-status and sync-workflow tests.
- Review the diff for test-only changes and no added cases.
- Run `git diff --check`.

## Coverage decision

Dedicated regression coverage of the test environment helpers is intentionally dropped; their isolation behavior remains in use.

Completed: 2026-09-06. Removed the three helper tests and their README claim.
The remaining component suite (137 tests) and Node syntax checks passed.
Git isolation helpers and all production files are unchanged.
