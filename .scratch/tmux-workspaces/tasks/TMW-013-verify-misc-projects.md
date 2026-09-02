# TMW-013: Verify miscellaneous-project launcher behavior

Status: pending

Area: Verification

Depends on: TMW-005, TMW-009

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Exercise fixed-project start, stop, repetition, layout, naming, and missing-project behavior in isolation.

## Acceptance checklist

- [ ] Start twice and confirm no sessions or windows are duplicated.
- [ ] Confirm all configured projects use the expected session names, layouts, commands, and selected windows.
- [ ] Stop twice and confirm both runs succeed.
- [ ] Test at least one missing configured project and confirm it is reported.
- [ ] Confirm a missing project does not prevent other projects from being processed or make the group fail.
- [ ] Record the focused verification evidence.

## Verification evidence

_Add evidence here when completing the task._

