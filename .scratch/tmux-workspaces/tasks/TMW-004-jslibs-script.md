# TMW-004: Implement `jslibs.sh`

Status: pending

Area: Group launchers

Depends on: TMW-001

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Replace the JavaScript-library start/stop pair with one discovery-based action launcher.

## Acceptance checklist

- [ ] Create executable `data/home/projects/workspaces/jslibs.sh`.
- [ ] Use `$HOME/projects/personal/mrzli-jslib` as the discovery root.
- [ ] On start, report and safely skip a missing discovery root.
- [ ] Discover only immediate child directories containing `.git`.
- [ ] Preserve the `jslib-<repository-name>` naming rule and leave existing sessions unchanged.
- [ ] Preserve `nvim`, `codex`, and `shell` windows, their existing commands, and `nvim` as the selected window.
- [ ] On stop, stop sessions beginning with `jslib-` and succeed when tmux or matching sessions are absent.
- [ ] Stop processing does not accidentally hide relevant pipeline or tmux failures.
- [ ] The script follows the TMW-001 action and failure contract.

## Verification evidence

_Add evidence here when completing the task._

