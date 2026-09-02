# TMW-010: Verify hub launcher behavior

Status: pending

Area: Verification

Depends on: TMW-002, TMW-009

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Exercise hub start, stop, repetition, and missing-root behavior in isolation.

## Acceptance checklist

- [ ] Start twice and confirm no sessions or windows are duplicated.
- [ ] Stop twice and confirm both runs succeed.
- [ ] Test at least one missing hub root and confirm it is reported.
- [ ] Confirm a missing root does not prevent other hub sessions from being processed.
- [ ] Confirm a missing root does not make an otherwise successful start fail.
- [ ] Record the focused verification evidence.

## Verification evidence

_Add evidence here when completing the task._
