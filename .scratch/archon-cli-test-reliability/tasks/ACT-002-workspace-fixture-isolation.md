# ACT-002: Isolate workspace adapter cases

Status: pending

Area: Workspace integration tests

Depends on: ACT-001

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Outcome

Make non-interactive workspace tests independent of the invoking terminal and other test cases.

## Expected files

`tests/archon-cli/test-workspaces-adapter.sh` and its fake-tmux fixtures.

## Acceptance checklist

- [ ] Give each adapter case a fresh temporary home, project roots, fake tmux state, and command log.
- [ ] Explicitly redirect non-interactive CLI stdin from `/dev/null`.
- [ ] Assert startup creates only the expected sessions without attachment or client switching.
- [ ] Keep startup and shutdown assertions scoped to each case's own calls.
- [ ] Ensure cleanup runs on failure and touches only that case's temporary fixtures.
- [ ] Use fake tmux exclusively; never launch real workspace applications.

## Verification

- Run adapter cases independently and together, with and without a terminal.
- Confirm that no prior case's calls or sessions affect a later case.
- Run `tests/archon-cli/run.sh` and whitespace checks.

