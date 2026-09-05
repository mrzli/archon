# ATP-004: Reduce duplicated workspace command transcripts

Status: pending

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Scope

`components/archon-cli/tests/workspaces/flashcards.test.mjs`, `jslibs.test.mjs`, and `misc-projects.test.mjs`.

Production changes and new tests are prohibited.

## Acceptance checklist

- [ ] Prune repeated full editor-session command transcripts from existing group cases; do not replace them with another shared transcript generator.
- [ ] Keep existing assertions or simplify their projections to retain group-specific session names, directory arguments, and development commands.
- [ ] Retain discovery, missing-directory, repeat-start/stop, and failure-propagation cases.
- [ ] Leave detailed shared creation and rollback coverage in `tmux.test.mjs` intact.
- [ ] Remove only test helper code made unnecessary by this pruning; add no new test cases, fixtures, or production injection points.

## Verification

- Run existing workspace module tests and the adapter.
- Review the diff for test-only changes and no added cases.
- Run `git diff --check`.

## Coverage decision

Group tests stop independently repeating every shared window-creation step. Shared helper tests retain detailed command sequencing.
