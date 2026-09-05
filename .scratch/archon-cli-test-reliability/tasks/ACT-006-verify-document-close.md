# ACT-006: Verify, document, and close the proposal

Status: completed

Area: Documentation and final verification

Depends on: ACT-001 through ACT-005

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Outcome

Record complete evidence for the specification and move enduring guidance into maintained documentation.

## Expected files

`components/archon-cli/tests/README.md`, installation documentation, and this planning directory.

## Acceptance checklist

- [x] Document fixture isolation rules, terminal-test prerequisites, and how to run the complete suite.
- [x] Document the shared installation boundary where it is maintained.
- [x] Run `tests/archon-cli/run.sh`, which includes the component suite, both with and without a terminal.
- [x] Run Node syntax checks for changed executables/modules and individual Bash checks for changed scripts.
- [x] Run ShellCheck when available and explicitly record any unavailable checks.
- [x] Run `git diff --check` and `git diff --cached --check` when implementation changes are staged.
- [x] Confirm all four specification areas have acceptance evidence and no real home, tmux server, credentials, or full setup execution was used.
- [x] Record results in the tasks and mark completed tasks accordingly.
- [x] Only after required work and verification are complete, mark the spec and task index completed and archived.

## Verification

- Audit every acceptance case in the source spec against test coverage or recorded focused verification.
- Verify relative documentation links resolve.
- Review the final diff for unrelated changes and accidental production behavior changes.

Completed: 2026-09-06. Final terminal and non-terminal suite runs passed,
including PTY attachment, shared installation/replacement, and conflicting Git
environment checks. Node syntax, individual Bash syntax (including fake tmux),
and whitespace checks passed. ShellCheck was unavailable and reported as skipped.
Durable guidance is in the test README and root installation README. The spec
and task index are archived as the completed requirements and verification record.
