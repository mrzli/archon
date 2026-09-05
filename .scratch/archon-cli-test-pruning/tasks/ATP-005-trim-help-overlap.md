# ATP-005: Trim overlapping help and alias checks

Status: pending

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Scope

`components/archon-cli/tests/exit-statuses.test.mjs`.

Production changes and new tests are prohibited.

## Acceptance checklist

- [ ] Remove redundant help variants where existing help-success and alias-forwarding cases already protect the same behavior.
- [ ] Retain successful root/domain help coverage and direct-command alias forwarding.
- [ ] Do not rely solely on equality of alias and full-command exit codes: two failures can be equal. Retain a successful-help expectation for each retained alias mapping, simplifying the existing case if needed.
- [ ] Keep unsupported nested abbreviations and invalid-option coverage for separately implemented parsers.
- [ ] Keep operational failure tests; remove only imports or fixture code made unused by the actual pruning.

## Verification

- Run the existing exit-status suite.
- Review the diff for test-only changes and no added cases.
- Run `git diff --check`.

## Coverage decision

Some spelling/entry-point combinations cease to have standalone tests; the retained help and alias cases still establish success and forwarding.
