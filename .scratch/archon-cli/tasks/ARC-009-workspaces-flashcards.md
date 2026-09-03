# ARC-009: Convert the flashcards workspace group

Status: proposed

Area: Workspaces

Depends on: ARC-008

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Route flashcards workspace operations to JavaScript while other groups still
delegate to Bash.

## Acceptance checklist

- [ ] Flashcards session definitions and operations are implemented in JavaScript.
- [ ] Named and aggregate calls route flashcards to the new implementation.
- [ ] Other groups remain delegated to their legacy launchers.
- [ ] Shared workspace primitives are introduced only as needed by flashcards.

## Verification

- Verify missing directories, repeated start/stop, exact windows and commands,
  layout selection, and injected failures against the legacy behavior.
- Run Node syntax checks and `git diff --check`.
