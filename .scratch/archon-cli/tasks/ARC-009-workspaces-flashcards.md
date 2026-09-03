# ARC-009: Convert the flashcards workspace group

Status: completed

Area: Workspaces

Depends on: ARC-008

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Route flashcards workspace operations to JavaScript while other groups still
delegate to Bash.

## Acceptance checklist

- [x] Flashcards session definitions and operations are implemented in JavaScript.
- [x] Named and aggregate calls route flashcards to the new implementation.
- [x] Other groups remain delegated to their legacy launchers.
- [x] Shared workspace primitives are introduced only as needed by flashcards.

## Verification

- Verify missing directories, repeated start/stop, exact windows and commands,
  layout selection, and injected failures against the legacy behavior.
- Run Node syntax checks and `git diff --check`.

## Verification evidence

Added a JavaScript flashcards handler and the shared tmux primitives needed to
create editor, Codex, optional development, and shell windows and to start or
stop sessions repeat-safely. The workspace orchestrator routes flashcards to
the handler while jslibs, miscellaneous projects, and hubs still use their
legacy launchers. The transitional workspace README reflects the mixed state.

The flashcards unit tests verify exact frontend and backend tmux operations,
commands, selected layout, repeated starts and stops, a missing directory, and
an injected session-creation failure that does not prevent the remaining
session. Workspace orchestration tests and both fake-tmux integration tests
passed, as did all seven root-command tests, both installation-layout tests,
and all seven unchanged legacy workspace tests. Relevant Node and Bash syntax
checks and `git diff --check` passed; ShellCheck was unavailable.
