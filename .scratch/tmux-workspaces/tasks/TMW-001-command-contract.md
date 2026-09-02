# TMW-001: Define the launcher command contract

Status: completed

Area: Interface

Depends on: None

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Define the consistent action, exit-status, and compatibility rules used by all replacement launchers.

## Acceptance checklist

- [x] Every replacement script accepts exactly one `start` or `stop` argument.
- [x] A missing or unsupported action prints usage and exits nonzero.
- [x] Missing configured directories are reported skips and do not make an otherwise successful group fail.
- [x] Actual tmux command errors make the relevant group script fail.
- [x] Existing tmux session names, window names, commands, and layouts remain unchanged.
- [x] Implementation stays within each group script; no shared shell library is introduced.

## Contract

- Launchers require exactly one argument and dispatch only `start` or `stop`.
- Invalid invocation prints `Usage: <script> {start|stop}` to standard error and exits with status 2.
- A missing configured directory is reported to standard error and skipped. It is not a group failure.
- Existing sessions are left unchanged during start, and absent sessions are ignored during stop.
- A tmux operation attempted for a present project or session propagates failure through a nonzero group exit.
- Each group owns its definitions and tmux operations directly; there is no shared shell library.

## Verification evidence

The action, usage, missing-directory, idempotency, failure, compatibility, and implementation-locality rules above define the interface used by TMW-002 through TMW-006.
