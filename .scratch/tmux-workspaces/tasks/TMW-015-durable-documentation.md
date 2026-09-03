# TMW-015: Document the completed launcher structure

Status: completed

Area: Documentation

Depends on: TMW-007, TMW-008, TMW-010, TMW-011, TMW-012, TMW-013, TMW-014

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Move enduring operational knowledge from the proposal into durable project documentation.

## Acceptance checklist

- [x] Document the five final launcher filenames.
- [x] Document each group's responsibility.
- [x] Document the `start|stop` invocation syntax.
- [x] Document aggregate start attachment/switch behavior and partial-failure behavior.
- [x] Mention that `projects/workspaces` is a managed replacement directory, so setup removes obsolete destination launchers.
- [x] Keep documentation consistent with the verified implementation.

## Verification evidence

Added the durable `Tmux Workspaces` section to the root README. It lists all five launchers and responsibilities, invocation syntax, idempotent and missing-directory behavior, aggregate attachment/switch and failure semantics, reverse stop order, and the managed replacement-directory consequence.
