# TMW-003: Implement `flashcards.sh`

Status: pending

Area: Group launchers

Depends on: TMW-001

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Replace the flashcards start/stop pair with one action-based launcher and one shared set of project definitions.

## Acceptance checklist

- [ ] Create executable `data/home/projects/workspaces/flashcards.sh`.
- [ ] Define frontend and backend metadata once for both actions.
- [ ] Preserve `flashcards-fe` at `$HOME/projects/personal/mrzli/flashcards-fe` and `flashcards-be` at `$HOME/projects/personal/mrzli/flashcards-be`.
- [ ] On start, report and skip a missing project while continuing with the other project.
- [ ] On start, leave existing sessions unchanged.
- [ ] Preserve `nvim`, `codex`, `dev`, and `shell` windows and select `nvim` after creation.
- [ ] Preserve `nvim .`, `codex resume --last`, frontend `bun run dev`, and backend `pnpm run dev` commands.
- [ ] On stop, use the shared definitions and succeed when either session is absent.
- [ ] The script follows the TMW-001 action and failure contract.

## Verification evidence

_Add evidence here when completing the task._

