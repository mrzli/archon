# TMW-002: Implement `hubs.sh`

Status: pending

Area: Group launchers

Depends on: TMW-001

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Replace the broad directory-session start/stop pair with one action-based launcher for persistent shell landing points.

## Acceptance checklist

- [ ] Create executable `data/home/projects/workspaces/hubs.sh`.
- [ ] Manage `workspaces` at `$HOME/projects/workspaces`, `projects` at `$HOME/projects/personal`, and `libs` at `$HOME/projects/personal/mrzli-jslib`.
- [ ] Keep hub definitions straightforward to extend with other broad directory roots later.
- [ ] On start, report and skip each missing root while continuing with the others.
- [ ] On start, leave existing sessions unchanged.
- [ ] New sessions contain one `shell` window, matching current behavior.
- [ ] On stop, stop all three sessions and succeed when any session is absent.
- [ ] The script follows the TMW-001 action and failure contract.

## Verification evidence

_Add evidence here when completing the task._
