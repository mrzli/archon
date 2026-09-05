# ACF-001: Roll back partially created workspace sessions

Status: pending

Area: Workspaces

Depends on: none

Source: [Archon CLI functional improvement tasks](../tasks.md)

## Outcome

Make workspace session creation failure-atomic so an incomplete session from a
failed start cannot prevent a later start from creating the complete session.

## Acceptance checklist

- [ ] Add isolated tests that reproduce a failure after session creation and
      demonstrate that the current invocation cleans up its partial session.
- [ ] Do not attempt cleanup when `tmux new-session` itself fails.
- [ ] After any later setup operation fails, attempt
      `tmux kill-session -t <session>` for the session created by that
      invocation.
- [ ] Return nonzero and retain reporting of the original setup failure when
      cleanup succeeds.
- [ ] Report cleanup failure and return nonzero when killing the partial
      session also fails.
- [ ] Never kill a session that existed before the invocation.
- [ ] Demonstrate that retrying start after an injected partial failure creates
      the complete expected session.
- [ ] Keep processing later sessions in the same group after one session fails.
- [ ] Keep aggregate execution processing later groups after one group fails.
- [ ] Preserve successful workspace creation, repeat-start behavior, stop
      behavior, session definitions, and command ordering.
- [ ] Use fake tmux state only; do not contact the user's tmux server.
- [ ] Run the complete canonical CLI suite at this checkpoint.

## Verification

- Run focused workspace tests with failures injected at `new-session` and at
  each subsequent `send-keys`, `new-window`, and `select-window` stage.
- Verify fake tmux call order, session state, messages, and return statuses for
  successful cleanup and cleanup failure.
- Run `tests/archon-cli/run.sh`.
- Run `git diff --check`.
