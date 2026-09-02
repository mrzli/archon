# TMW-006: Implement `all.sh`

Status: pending

Area: Aggregate launcher

Depends on: TMW-001, TMW-002, TMW-003, TMW-004, TMW-005

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Replace the aggregate start/stop pair with one action launcher that exposes partial failures.

## Acceptance checklist

- [ ] Create executable `data/home/projects/workspaces/all.sh`.
- [ ] Resolve child script paths relative to `all.sh`, independent of the caller's working directory.
- [ ] Start hubs, flashcards, JavaScript libraries, and miscellaneous projects.
- [ ] Continue invoking remaining start groups after a failure and identify every failing group.
- [ ] Attach to `workspaces` outside tmux only when every start group succeeds.
- [ ] Switch the current client to `workspaces` inside tmux only when every start group succeeds.
- [ ] Return nonzero without attaching or switching when any start group fails.
- [ ] Stop groups in current reverse order: miscellaneous projects, JavaScript libraries, flashcards, hubs.
- [ ] Continue invoking remaining stop groups, report each failure, and return nonzero if any group fails.
- [ ] The script follows the TMW-001 action contract.

## Verification evidence

_Add evidence here when completing the task._
