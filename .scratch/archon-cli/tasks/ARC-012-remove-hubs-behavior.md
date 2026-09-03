# ARC-012: Remove hubs and aggregate attachment behavior

Status: completed

Area: Workspaces

Depends on: ARC-011

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Apply the intentional final workspace behavior change after all retained groups
run in JavaScript.

## Acceptance checklist

- [x] Hubs are absent from the aggregate and `--group`/`-g` choices.
- [x] Aggregate start no longer attaches or switches tmux clients.
- [x] Aggregate start and stop retain forward/reverse ordering and failure aggregation.
- [x] Legacy shell files remain temporarily for rollback.

## Verification

- Test final grammar, ordering, partial failures, and absence of attach/switch
  calls using fake tmux.
- Run Node syntax checks and `git diff --check`.

Completed with Node orchestration tests, the fake-tmux workspace integration
test, root CLI and installation regressions, Node and Bash syntax checks, and
`git diff --check`.
