# ARC-012: Remove hubs and aggregate attachment behavior

Status: proposed

Area: Workspaces

Depends on: ARC-011

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Apply the intentional final workspace behavior change after all retained groups
run in JavaScript.

## Acceptance checklist

- [ ] Hubs are absent from the aggregate and `--group`/`-g` choices.
- [ ] Aggregate start no longer attaches or switches tmux clients.
- [ ] Aggregate start and stop retain forward/reverse ordering and failure aggregation.
- [ ] Legacy shell files remain temporarily for rollback.

## Verification

- Test final grammar, ordering, partial failures, and absence of attach/switch
  calls using fake tmux.
- Run Node syntax checks and `git diff --check`.
