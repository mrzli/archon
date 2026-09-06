# ACS-003: Share editor-session lifecycle

Status: pending

Depends on: ACS-002 (execution order; no technical dependency)

Source: [Task index](../tasks.md)

## Outcome

Make flashcards and miscellaneous-project modules mainly describe sessions,
with one shared helper managing their repeated lifecycle.

## Acceptance checklist

- [ ] Extract repeated directory/existing-session checks, start/stop handling,
      error reporting, and failure accumulation into a small shared helper.
- [ ] Keep configured session names, directories, windows, and development
      commands unchanged.
- [ ] Preserve missing-directory skips and repeat-safe starts/stops.
- [ ] Keep rollback ownership in the existing tmux editor-session operation;
      report both setup and cleanup failures as before.
- [ ] Continue attempting remaining sessions after a failure.
- [ ] Reuse editor-start behavior for jslibs only where it avoids duplication
      without extra mode flags or a configurable lifecycle framework.
- [ ] Preserve jslibs discovery and prefix-based stopping; do not introduce new
      per-directory checks or change general's shell-only session behavior.
- [ ] Keep current process injection for this checkpoint; the operations object
      is a separate follow-up task.

## Verification

Run existing workspace group and tmux tests and fake-tmux adapter checks.
Verify rollback, cleanup failure, repeat-safe behavior, missing directories,
group ordering, and continued processing. Run the checks in the task index.
