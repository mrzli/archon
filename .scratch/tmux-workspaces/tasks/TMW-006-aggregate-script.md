# TMW-006: Implement `all.sh`

Status: completed

Area: Aggregate launcher

Depends on: TMW-001, TMW-002, TMW-003, TMW-004, TMW-005

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Replace the aggregate start/stop pair with one action launcher that exposes partial failures.

## Acceptance checklist

- [x] Create executable `data/home/projects/workspaces/all.sh`.
- [x] Resolve child script paths relative to `all.sh`, independent of the caller's working directory.
- [x] Start hubs, flashcards, JavaScript libraries, and miscellaneous projects.
- [x] Continue invoking remaining start groups after a failure and identify every failing group.
- [x] Attach to `workspaces` outside tmux only when every start group succeeds.
- [x] Switch the current client to `workspaces` inside tmux only when every start group succeeds.
- [x] Return nonzero without attaching or switching when any start group fails.
- [x] Stop groups in current reverse order: miscellaneous projects, JavaScript libraries, flashcards, hubs.
- [x] Continue invoking remaining stop groups, report each failure, and return nonzero if any group fails.
- [x] The script follows the TMW-001 action contract.

## Verification evidence

Implemented relative child resolution and explicit start/stop group order in `all.sh`. Child failures are accumulated and identified, all groups are attempted, and attachment or client switching occurs only after a completely successful start.
