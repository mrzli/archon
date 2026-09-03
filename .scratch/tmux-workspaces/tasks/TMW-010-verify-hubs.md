# TMW-010: Verify hub launcher behavior

Status: completed

Area: Verification

Depends on: TMW-002, TMW-009

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Exercise hub start, stop, repetition, and missing-root behavior in isolation.

## Acceptance checklist

- [x] Start twice and confirm no sessions or windows are duplicated.
- [x] Stop twice and confirm both runs succeed.
- [x] Test at least one missing hub root and confirm it is reported.
- [x] Confirm a missing root does not prevent other hub sessions from being processed.
- [x] Confirm a missing root does not make an otherwise successful start fail.
- [x] Record the focused verification evidence.

## Verification evidence

The `hubs start and stop` isolated test passed. It starts twice with the libraries root absent, confirms the skip message and successful creation of both remaining one-window sessions without duplication, then stops twice and confirms all hub sessions are absent.
