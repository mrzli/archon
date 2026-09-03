# TMW-008: Run static and command-interface validation

Status: completed

Area: Verification

Depends on: TMW-002, TMW-003, TMW-004, TMW-005, TMW-006, TMW-007

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Validate syntax, lint, action rejection, formatting, and scope without running the workstation setup.

## Acceptance checklist

- [x] Run `bash -n` on all five replacement scripts.
- [x] Run ShellCheck on all five scripts when ShellCheck is available and resolve relevant findings.
- [x] Confirm every script rejects an absent action.
- [x] Confirm every script rejects an invalid action.
- [x] Run `git diff --check`.
- [x] Review the diff and confirm every changed line traces to the spec.
- [x] Do not run the complete `setup.sh` as verification.

## Verification evidence

All five replacement scripts passed one combined `bash -n` invocation. ShellCheck was not installed, so its conditional check was skipped. Each executable returned status 2 for both absent and invalid actions. `git diff --check` passed, and review of the branch diff confirmed that it contains only the launcher restructuring and its task records. The complete setup script was not run.
