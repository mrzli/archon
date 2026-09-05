# ATP-001: Remove tests of Git test helpers

Status: pending

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Scope

`components/archon-cli/tests/git-environment.test.mjs` and its description in the test README.

Production changes and new tests are prohibited.

## Acceptance checklist

- [ ] Delete the three tests in `git-environment.test.mjs` and the file itself.
- [ ] Keep `createGitEnvironment`, `withGitFixture`, and their production-workflow test callers unchanged.
- [ ] Remove the README claim that the suite reruns Git workflows under synthetic conflicting settings.
- [ ] Do not introduce replacement helper tests or new fixture machinery.

## Verification

- Run the existing component suite, including repository-status and sync-workflow tests.
- Review the diff for test-only changes and no added cases.
- Run `git diff --check`.

## Coverage decision

Dedicated regression coverage of the test environment helpers is intentionally dropped; their isolation behavior remains in use.
