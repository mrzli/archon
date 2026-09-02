# TMW-011: Verify flashcards launcher behavior

Status: pending

Area: Verification

Depends on: TMW-003, TMW-009

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Exercise flashcards start, stop, repetition, layout, commands, and missing-project behavior in isolation.

## Acceptance checklist

- [ ] Start twice and confirm no sessions or windows are duplicated.
- [ ] Confirm frontend and backend session roots, window layouts, commands, and selected windows.
- [ ] Stop twice and confirm both runs succeed.
- [ ] Test one missing flashcards project and confirm it is reported.
- [ ] Confirm the missing project does not prevent the other project from being processed or make the group fail.
- [ ] Record the focused verification evidence.

## Verification evidence

_Add evidence here when completing the task._

