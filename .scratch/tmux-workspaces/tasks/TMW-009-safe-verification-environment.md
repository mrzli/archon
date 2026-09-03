# TMW-009: Prepare isolated tmux behavior verification

Status: completed

Area: Verification

Depends on: TMW-002, TMW-003, TMW-004, TMW-005, TMW-006

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Create a safe focused-check setup that cannot disturb the user's real tmux sessions or project data.

## Acceptance checklist

- [x] Use isolated tmux state or a command stub for launcher checks.
- [x] Use temporary project roots or controlled directory fixtures for present and missing-directory cases.
- [x] Prevent launched editor, Codex, and development commands from affecting real projects.
- [x] Provide a repeatable way to inspect sessions, windows, child invocation order, exit statuses, and attach/switch attempts.
- [x] Clean up only the isolated verification state after checks.

## Verification evidence

Added `tests/tmux-workspaces/test-launchers.sh` and a fake `tmux` executable. Each test case receives a temporary HOME and state directory, while the fake records sessions, roots, windows, commands, selections, attach/switch calls, and injected failures without launching real programs. The harness self-test passed and its EXIT trap removes only its own `mktemp` directory.
