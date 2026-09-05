# ATP-003: Prune mock-only and redundant workspace checks

Status: pending

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Scope

`tests/archon-cli/test-workspaces-adapter.sh`.

Production changes and new tests are prohibited.

## Acceptance checklist

- [ ] Delete `test_fake_attachment_targets` and its runner registration.
- [ ] Keep fake tmux target validation unchanged and retain all actual CLI attachment cases.
- [ ] Delete individual session existence/absence assertions already implied by the same case's exact `assert_sessions` result.
- [ ] Remove `assert_session_exists` and `assert_session_absent` once no callers remain.
- [ ] Keep exact session-set checks after start and stop, attachment assertions, fixture isolation, explicit stdin handling, and terminal timeouts.

## Verification

- Run the existing workspace adapter with terminal and non-terminal stdin.
- Review the diff for test-only changes and no added cases.
- Run `git diff --check`.

## Coverage decision

The direct test of the fake's rejection behavior is intentionally dropped. Actual CLI attachment and session-state checks remain.
