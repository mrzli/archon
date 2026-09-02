# TMW-007: Remove the replaced launcher files

Status: pending

Area: Migration

Depends on: TMW-002, TMW-003, TMW-004, TMW-005, TMW-006

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Remove the ten legacy start/stop files after their replacements are ready and update real references.

## Acceptance checklist

- [ ] Remove `all-start.sh` and `all-stop.sh`.
- [ ] Remove `flashcards-start.sh` and `flashcards-stop.sh`.
- [ ] Remove `jslibs-start.sh` and `jslibs-stop.sh`.
- [ ] Remove `other-start.sh` and `other-stop.sh`.
- [ ] Remove `workspaces-start.sh` and `workspaces-stop.sh`.
- [ ] Search the repository for removed filenames and update all real callers or documentation.
- [ ] Confirm `data/home-replace-directories.txt` still intentionally manages the entire `projects/workspaces` destination.

## Verification evidence

_Add evidence here when completing the task._

