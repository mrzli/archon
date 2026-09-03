# TMW-005: Implement `misc-projects.sh`

Status: completed

Area: Group launchers

Depends on: TMW-001

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Replace the miscellaneous-project start/stop pair with one launcher whose fixed project list has one source of truth.

## Acceptance checklist

- [x] Create executable `data/home/projects/workspaces/misc-projects.sh`.
- [x] Define `mrzli/docs`, `mrzli/repos`, `mrzli/archon`, and `mrzli/js-templates` once for both actions.
- [x] Use `$HOME/projects/personal` as the project root.
- [x] Preserve the `project-<slash-separated-path-with-dashes>` session naming rule.
- [x] On start, report and skip each missing project while continuing with the others.
- [x] On start, leave existing sessions unchanged.
- [x] Preserve `nvim`, `codex`, and `shell` windows, their existing commands, and `nvim` as the selected window.
- [x] On stop, derive sessions from the shared project list and succeed when sessions are absent.
- [x] The script follows the TMW-001 action and failure contract.

## Verification evidence

Implemented the four projects as one shared list used by both actions in `misc-projects.sh`. Session names, the existing three-window layout, commands, missing-directory skips, idempotency, and tmux failure propagation are preserved.
