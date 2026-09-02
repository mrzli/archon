# TMW-008: Run static and command-interface validation

Status: pending

Area: Verification

Depends on: TMW-002, TMW-003, TMW-004, TMW-005, TMW-006, TMW-007

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Validate syntax, lint, action rejection, formatting, and scope without running the workstation setup.

## Acceptance checklist

- [ ] Run `bash -n` on all five replacement scripts.
- [ ] Run ShellCheck on all five scripts when ShellCheck is available and resolve relevant findings.
- [ ] Confirm every script rejects an absent action.
- [ ] Confirm every script rejects an invalid action.
- [ ] Run `git diff --check`.
- [ ] Review the diff and confirm every changed line traces to the spec.
- [ ] Do not run the complete `setup.sh` as verification.

## Verification evidence

_Add evidence here when completing the task._

