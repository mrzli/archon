# ARC-001: Establish baseline contract coverage

Status: proposed

Area: Verification

Depends on: None

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Capture enough current behavior to detect regressions while entry points move.

## Acceptance checklist

- [ ] Projects and libraries help, dispatch, and exit statuses are covered.
- [ ] Destructive commands are exercised only with dry-run and controlled roots.
- [ ] The existing isolated workspace launcher suite passes unchanged.
- [ ] The harness can compare legacy and replacement entry points.
- [ ] No production behavior changes.

## Verification

- Run all new baseline checks.
- Run `tests/tmux-workspaces/test-launchers.sh`.
- Run `git diff --check`.
