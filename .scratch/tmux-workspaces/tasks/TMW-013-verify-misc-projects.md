# TMW-013: Verify miscellaneous-project launcher behavior

Status: completed

Area: Verification

Depends on: TMW-005, TMW-009

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Exercise fixed-project start, stop, repetition, layout, naming, and missing-project behavior in isolation.

## Acceptance checklist

- [x] Start twice and confirm no sessions or windows are duplicated.
- [x] Confirm all configured projects use the expected session names, layouts, commands, and selected windows.
- [x] Stop twice and confirm both runs succeed.
- [x] Test at least one missing configured project and confirm it is reported.
- [x] Confirm a missing project does not prevent other projects from being processed or make the group fail.
- [x] Record the focused verification evidence.

## Verification evidence

The `miscellaneous projects start and stop` isolated test passed. It verifies repeated actions, all four derived session names, roots, exact window layouts, commands, and selections. A second fixture omits `mrzli/repos`, confirms its skip message and successful creation of all three remaining project sessions.
