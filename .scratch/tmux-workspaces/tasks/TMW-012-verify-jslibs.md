# TMW-012: Verify JavaScript-library launcher behavior

Status: completed

Area: Verification

Depends on: TMW-004, TMW-009

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Exercise repository discovery, start, stop, repetition, layout, and missing-root behavior in isolation.

## Acceptance checklist

- [x] Provide repository and non-repository immediate child fixtures and confirm only repositories create sessions.
- [x] Start twice and confirm no sessions or windows are duplicated.
- [x] Confirm session naming, window layouts, commands, and selected windows.
- [x] Stop twice and confirm both runs succeed with matching, nonmatching, and absent sessions.
- [x] Test a missing discovery root and confirm it is reported without making an otherwise successful group fail.
- [x] Record the focused verification evidence.

## Verification evidence

The `JavaScript libraries start and stop` isolated test passed. Immediate Git, non-Git, and nested fixtures verify discovery scope; repeated starts preserve exact layouts and commands. Stop succeeds with matching, nonmatching, and absent sessions, while an injected unexpected list failure remains visible. A missing discovery root is reported and returns success.
