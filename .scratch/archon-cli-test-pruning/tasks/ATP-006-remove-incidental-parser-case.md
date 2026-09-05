# ATP-006: Remove the incidental parser-permissiveness test

Status: pending

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Scope

`components/archon-cli/tests/libs-github-inventory.test.mjs`.

Production changes and new tests are prohibited.

## Acceptance checklist

- [ ] Delete `library GitHub non-name fields retain current values`.
- [ ] Keep normal inventory parsing and malformed-input/name-field rejection cases.
- [ ] Do not change parser behavior or add stricter-validation tests.

## Verification

- Run the existing library inventory tests.
- Review the diff for test-only changes and no added cases.
- Run `git diff --check`.

## Coverage decision

Empty names and undefined flags are no longer pinned as a required contract by a dedicated test.
