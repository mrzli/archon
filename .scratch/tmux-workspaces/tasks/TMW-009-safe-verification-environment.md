# TMW-009: Prepare isolated tmux behavior verification

Status: pending

Area: Verification

Depends on: TMW-002, TMW-003, TMW-004, TMW-005, TMW-006

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Create a safe focused-check setup that cannot disturb the user's real tmux sessions or project data.

## Acceptance checklist

- [ ] Use isolated tmux state or a command stub for launcher checks.
- [ ] Use temporary project roots or controlled directory fixtures for present and missing-directory cases.
- [ ] Prevent launched editor, Codex, and development commands from affecting real projects.
- [ ] Provide a repeatable way to inspect sessions, windows, child invocation order, exit statuses, and attach/switch attempts.
- [ ] Clean up only the isolated verification state after checks.

## Verification evidence

_Add evidence here when completing the task._

