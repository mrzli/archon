# TMW-001: Define the launcher command contract

Status: pending

Area: Interface

Depends on: None

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Define the consistent action, exit-status, and compatibility rules used by all replacement launchers.

## Acceptance checklist

- [ ] Every replacement script accepts exactly one `start` or `stop` argument.
- [ ] A missing or unsupported action prints usage and exits nonzero.
- [ ] Missing configured directories are reported skips and do not make an otherwise successful group fail.
- [ ] Actual tmux command errors make the relevant group script fail.
- [ ] Existing tmux session names, window names, commands, and layouts remain unchanged.
- [ ] Implementation stays within each group script; no shared shell library is introduced.

## Verification evidence

_Add evidence here when completing the task._

