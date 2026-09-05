# ATP-004: Reduce duplicated workspace command transcripts

Status: completed

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Scope

`components/archon-cli/tests/workspaces/flashcards.test.mjs`, `jslibs.test.mjs`, and `misc-projects.test.mjs`.

Production changes and new tests are prohibited.

## Acceptance checklist

- [x] Prune repeated full editor-session command transcripts from existing group cases; do not replace them with another shared transcript generator.
- [x] Keep existing assertions or simplify their projections to retain group-specific session names, directory arguments, and development commands.
- [x] Retain discovery, missing-directory, repeat-start/stop, and failure-propagation cases.
- [x] Leave detailed shared creation and rollback coverage in `tmux.test.mjs` intact.
- [x] Remove only test helper code made unnecessary by this pruning; add no new test cases, fixtures, or production injection points.

## Verification

- Run existing workspace module tests and the adapter.
- Review the diff for test-only changes and no added cases.
- Run `git diff --check`.

## Coverage decision

Group tests stop independently repeating every shared window-creation step. Shared helper tests retain detailed command sequencing.

Completed: 2026-09-06. Pruned repeated editor-window transcripts and the misc
transcript generator. Existing group cases retain session/directory projections,
flashcards development commands, and repeat/failure behavior. All 33 existing
workspace module tests and five adapter cases passed. Shared tmux tests are
unchanged.
