# TMW-003: Implement `flashcards.sh`

Status: completed

Area: Group launchers

Depends on: TMW-001

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Replace the flashcards start/stop pair with one action-based launcher and one shared set of project definitions.

## Acceptance checklist

- [x] Create executable `data/home/projects/workspaces/flashcards.sh`.
- [x] Define frontend and backend metadata once for both actions.
- [x] Preserve `flashcards-fe` at `$HOME/projects/personal/mrzli/flashcards-fe` and `flashcards-be` at `$HOME/projects/personal/mrzli/flashcards-be`.
- [x] On start, report and skip a missing project while continuing with the other project.
- [x] On start, leave existing sessions unchanged.
- [x] Preserve `nvim`, `codex`, `dev`, and `shell` windows and select `nvim` after creation.
- [x] Preserve `nvim .`, `codex resume --last`, frontend `bun run dev`, and backend `pnpm run dev` commands.
- [x] On stop, use the shared definitions and succeed when either session is absent.
- [x] The script follows the TMW-001 action and failure contract.

## Verification evidence

Implemented shared parallel definitions for the two flashcards sessions in `flashcards.sh`. Start preserves the existing four-window layouts and commands, while both actions reuse the same session metadata and accumulate tmux failures without skipping the other configured project.
