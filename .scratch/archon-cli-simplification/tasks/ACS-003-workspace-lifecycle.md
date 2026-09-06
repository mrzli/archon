# ACS-003: Share editor-session lifecycle

Status: completed

Completed: 2026-09-06 (uncommitted)

Depends on: ACS-002 (execution order; no technical dependency)

Source: [Task index](../tasks.md)

## Outcome

Make flashcards and miscellaneous-project modules mainly describe sessions,
with one shared helper managing their repeated lifecycle.

## Acceptance checklist

- [x] Extract repeated directory/existing-session checks, start/stop handling,
      error reporting, and failure accumulation into a small shared helper.
- [x] Keep configured session names, directories, windows, and development
      commands unchanged.
- [x] Preserve missing-directory skips and repeat-safe starts/stops.
- [x] Keep rollback ownership in the existing tmux editor-session operation;
      report both setup and cleanup failures as before.
- [x] Continue attempting remaining sessions after a failure.
- [x] Reuse editor-start behavior for jslibs only where it avoids duplication
      without extra mode flags or a configurable lifecycle framework.
- [x] Preserve jslibs discovery and prefix-based stopping; do not introduce new
      per-directory checks or change general's shell-only session behavior.
- [x] Keep current process injection for this checkpoint; the operations object
      is a separate follow-up task.

## Verification

Run existing workspace group and tmux tests and fake-tmux adapter checks.
Verify rollback, cleanup failure, repeat-safe behavior, missing directories,
group ordering, and continued processing. Run the checks in the task index.

## Completion record

Added `workspaces/src/editor-sessions.mjs` with `manageEditorSessions` for
configured session lists and `startEditorSession` for shared existing-session
checks and setup/cleanup error reporting. Flashcards and miscellaneous projects
now supply session definitions. Jslibs reuses the startup helper while retaining
its discovery, root check, and prefix-based stopping. General and low-level tmux
operations are unchanged; no operations object or new tests were introduced.
Workspace AGENTS.md records ownership; READMEs remain usage-only.

Existing workspace tests passed, followed by `bash tests/archon-cli/run.sh`:
126 Node tests, five workspace adapter cases, one installation-layout case,
two migration cases, and Node/Bash syntax and whitespace checks all passed.
ShellCheck was unavailable. The complete suite ran outside the sandbox to
support its isolated Git subprocess fixtures. No commit was made.
