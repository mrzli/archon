# ACF-001: Roll back partially created workspace sessions

Status: completed

Completed: 2026-09-05

Area: Workspaces

Depends on: none

Source: [Archon CLI functional improvement tasks](../tasks.md)

## Outcome

Make workspace session creation failure-atomic so an incomplete session from a
failed start cannot prevent a later start from creating the complete session.

## Acceptance checklist

- [x] Add isolated tests that reproduce a failure after session creation and
      demonstrate that the current invocation cleans up its partial session.
- [x] Do not attempt cleanup when `tmux new-session` itself fails.
- [x] After any later setup operation fails, attempt
      `tmux kill-session -t <session>` for the session created by that
      invocation.
- [x] Return nonzero and retain reporting of the original setup failure when
      cleanup succeeds.
- [x] Report cleanup failure and return nonzero when killing the partial
      session also fails.
- [x] Never kill a session that existed before the invocation.
- [x] Demonstrate that retrying start after an injected partial failure creates
      the complete expected session.
- [x] Keep processing later sessions in the same group after one session fails.
- [x] Keep aggregate execution processing later groups after one group fails.
- [x] Preserve successful workspace creation, repeat-start behavior, stop
      behavior, session definitions, and command ordering.
- [x] Use fake tmux state only; do not contact the user's tmux server.
- [x] Run the complete canonical CLI suite at this checkpoint.

## Verification

- Run focused workspace tests with failures injected at `new-session` and at
  each subsequent `send-keys`, `new-window`, and `select-window` stage.
- Verify fake tmux call order, session state, messages, and return statuses for
  successful cleanup and cleanup failure.
- Run `tests/archon-cli/run.sh`.
- Run `git diff --check`.

Completed with isolated coverage for every session-setup stage, cleanup
success and failure, retry, existing-session preservation, and continued
processing. The canonical suite passed all 65 Node tests and 15 shell-suite
checks, plus Node and Bash syntax checks and `git diff --check`. ShellCheck was
unavailable and reported as skipped.
