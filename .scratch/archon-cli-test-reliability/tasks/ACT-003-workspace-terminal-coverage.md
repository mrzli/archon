# ACT-003: Verify automatic attachment through a terminal

Status: completed

Area: Workspace integration tests

Depends on: ACT-002

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Outcome

Test real CLI terminal detection and attachment wiring using a pseudo-terminal and fake tmux.

## Expected files

`tests/archon-cli/test-workspaces-adapter.sh`, `tests/tmux-workspaces/bin/tmux`, and focused workspace tests where needed.

## Acceptance checklist

- [x] Run the actual CLI through a platform-provided PTY utility; explicitly report missing prerequisites.
- [x] Bound terminal subprocess execution so regressions cannot hang verification.
- [x] Verify interactive aggregate startup outside tmux attaches exactly once to `main`.
- [x] Verify interactive named-group startup attaches to a session from that group.
- [x] Verify startup with `TMUX` set does not attach or switch clients.
- [x] Cover stop, help, and failed-start non-attachment at the lowest layer that protects each contract.
- [x] Make the fake record exact attachment targets and reject missing targets, including support for `=name` syntax.
- [x] Assert attachment creates no extra session.
- [x] Keep existing module policy coverage without repeating its entire matrix through the CLI.

## Verification

- Run focused terminal and non-terminal cases with fresh fixtures.
- Verify nonexistent fake attachment targets fail and valid exact targets succeed.
- Run the complete suite with and without a terminal; no real tmux server may be contacted.

Completed: 2026-09-06. All six adapter cases and the full suite passed with
terminal and non-terminal stdin. PTY runs are bounded to 15 seconds; fake tmux
rejects absent targets and records successful exact-target attachments. Existing
module tests cover stop, help, and failed-start non-attachment. ShellCheck was
unavailable.
