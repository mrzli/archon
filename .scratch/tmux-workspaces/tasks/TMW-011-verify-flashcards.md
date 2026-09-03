# TMW-011: Verify flashcards launcher behavior

Status: completed

Area: Verification

Depends on: TMW-003, TMW-009

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Exercise flashcards start, stop, repetition, layout, commands, and missing-project behavior in isolation.

## Acceptance checklist

- [x] Start twice and confirm no sessions or windows are duplicated.
- [x] Confirm frontend and backend session roots, window layouts, commands, and selected windows.
- [x] Stop twice and confirm both runs succeed.
- [x] Test one missing flashcards project and confirm it is reported.
- [x] Confirm the missing project does not prevent the other project from being processed or make the group fail.
- [x] Record the focused verification evidence.

## Verification evidence

The `flashcards start and stop` isolated test passed. It verifies repeated start and stop, both session roots, exact four-window layouts, editor/Codex/development commands, selected windows, and successful backend creation when the missing frontend is reported and skipped.
