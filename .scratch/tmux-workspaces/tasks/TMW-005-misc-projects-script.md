# TMW-005: Implement `misc-projects.sh`

Status: pending

Area: Group launchers

Depends on: TMW-001

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Replace the miscellaneous-project start/stop pair with one launcher whose fixed project list has one source of truth.

## Acceptance checklist

- [ ] Create executable `data/home/projects/workspaces/misc-projects.sh`.
- [ ] Define `mrzli/docs`, `mrzli/repos`, `mrzli/archon`, and `mrzli/js-templates` once for both actions.
- [ ] Use `$HOME/projects/personal` as the project root.
- [ ] Preserve the `project-<slash-separated-path-with-dashes>` session naming rule.
- [ ] On start, report and skip each missing project while continuing with the others.
- [ ] On start, leave existing sessions unchanged.
- [ ] Preserve `nvim`, `codex`, and `shell` windows, their existing commands, and `nvim` as the selected window.
- [ ] On stop, derive sessions from the shared project list and succeed when sessions are absent.
- [ ] The script follows the TMW-001 action and failure contract.

## Verification evidence

_Add evidence here when completing the task._

