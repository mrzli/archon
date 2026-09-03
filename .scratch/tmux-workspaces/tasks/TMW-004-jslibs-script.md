# TMW-004: Implement `jslibs.sh`

Status: completed

Area: Group launchers

Depends on: TMW-001

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Replace the JavaScript-library start/stop pair with one discovery-based action launcher.

## Acceptance checklist

- [x] Create executable `data/home/projects/workspaces/jslibs.sh`.
- [x] Use `$HOME/projects/personal/mrzli-jslib` as the discovery root.
- [x] On start, report and safely skip a missing discovery root.
- [x] Discover only immediate child directories containing `.git`.
- [x] Preserve the `jslib-<repository-name>` naming rule and leave existing sessions unchanged.
- [x] Preserve `nvim`, `codex`, and `shell` windows, their existing commands, and `nvim` as the selected window.
- [x] On stop, stop sessions beginning with `jslib-` and succeed when tmux or matching sessions are absent.
- [x] Stop processing does not accidentally hide relevant pipeline or tmux failures.
- [x] The script follows the TMW-001 action and failure contract.

## Verification evidence

Implemented immediate-child Git repository discovery and the preserved three-window layout in `jslibs.sh`. Stop captures `tmux list-sessions` before filtering, treats a missing server as an empty state, and retains kill and unexpected list failures in the group exit status.
