# ARC-001: Establish baseline contract coverage

Status: completed

Area: Verification

Depends on: None

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Capture enough current behavior to detect regressions while entry points move.

## Acceptance checklist

- [x] Projects and libraries help, dispatch, and exit statuses are covered.
- [x] Destructive commands are exercised only with dry-run and controlled roots.
- [x] The existing isolated workspace launcher suite passes unchanged.
- [x] The harness can compare legacy and replacement entry points.
- [x] No production behavior changes.

## Verification

- Run all new baseline checks.
- Run `tests/tmux-workspaces/test-launchers.sh`.
- Run `git diff --check`.

## Verification evidence

Added `tests/archon-cli/test-baseline.sh` with an isolated temporary filesystem
and fake `gh`. The harness covers global and command help, unknown commands,
unexpected options, exit statuses, and projects/libraries delete and prune
dry-runs. `PROJECTS_SCRIPT` and `LIBS_SCRIPT` can select relocated scripts for
later parity checks.

All four new baseline tests passed. All seven existing tmux-workspace tests
also passed unchanged. Both new shell files passed `bash -n`, `git diff --check`
passed, and ShellCheck was unavailable.
