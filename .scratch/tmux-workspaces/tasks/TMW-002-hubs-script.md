# TMW-002: Implement `hubs.sh`

Status: completed

Area: Group launchers

Depends on: TMW-001

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Replace the broad directory-session start/stop pair with one action-based launcher for persistent shell landing points.

## Acceptance checklist

- [x] Create executable `data/home/projects/workspaces/hubs.sh`.
- [x] Manage `workspaces` at `$HOME/projects/workspaces`, `projects` at `$HOME/projects/personal`, and `libs` at `$HOME/projects/personal/mrzli-jslib`.
- [x] Keep hub definitions straightforward to extend with other broad directory roots later.
- [x] On start, report and skip each missing root while continuing with the others.
- [x] On start, leave existing sessions unchanged.
- [x] New sessions contain one `shell` window, matching current behavior.
- [x] On stop, stop all three sessions and succeed when any session is absent.
- [x] The script follows the TMW-001 action and failure contract.

## Verification evidence

Implemented the three parallel session/directory definitions in `hubs.sh`. The launcher validates its action, skips and reports missing roots, preserves existing sessions, creates only the `shell` window, ignores absent sessions during stop, and accumulates tmux operation failures.
