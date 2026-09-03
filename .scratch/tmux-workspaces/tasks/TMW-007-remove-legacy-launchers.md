# TMW-007: Remove the replaced launcher files

Status: completed

Area: Migration

Depends on: TMW-002, TMW-003, TMW-004, TMW-005, TMW-006

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Remove the ten legacy start/stop files after their replacements are ready and update real references.

## Acceptance checklist

- [x] Remove `all-start.sh` and `all-stop.sh`.
- [x] Remove `flashcards-start.sh` and `flashcards-stop.sh`.
- [x] Remove `jslibs-start.sh` and `jslibs-stop.sh`.
- [x] Remove `other-start.sh` and `other-stop.sh`.
- [x] Remove `workspaces-start.sh` and `workspaces-stop.sh`.
- [x] Search the repository for removed filenames and update all real callers or documentation.
- [x] Confirm `data/home-replace-directories.txt` still intentionally manages the entire `projects/workspaces` destination.

## Verification evidence

Removed all ten legacy launchers. A repository-wide search found no real callers outside those aggregate legacy scripts; remaining filename mentions are historical context in the specification and this migration record. `data/home-replace-directories.txt` still lists `projects/workspaces`, ensuring obsolete destination files are removed during setup.
