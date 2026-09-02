# TMW-012: Verify JavaScript-library launcher behavior

Status: pending

Area: Verification

Depends on: TMW-004, TMW-009

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Exercise repository discovery, start, stop, repetition, layout, and missing-root behavior in isolation.

## Acceptance checklist

- [ ] Provide repository and non-repository immediate child fixtures and confirm only repositories create sessions.
- [ ] Start twice and confirm no sessions or windows are duplicated.
- [ ] Confirm session naming, window layouts, commands, and selected windows.
- [ ] Stop twice and confirm both runs succeed with matching, nonmatching, and absent sessions.
- [ ] Test a missing discovery root and confirm it is reported without making an otherwise successful group fail.
- [ ] Record the focused verification evidence.

## Verification evidence

_Add evidence here when completing the task._

