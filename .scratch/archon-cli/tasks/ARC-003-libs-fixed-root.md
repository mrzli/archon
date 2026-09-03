# ARC-003: Decouple the libraries target from script location

Status: proposed

Area: Libraries

Depends on: ARC-001

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Make the legacy libraries command operate on its fixed root so it can later
move without changing its target.

## Acceptance checklist

- [ ] The target resolves to `~/projects/personal/mrzli-jslib` independently of script location.
- [ ] Tests can inject a temporary home/root without affecting production defaults.
- [ ] Deletion safety checks the exact resolved root rather than its basename.
- [ ] All other command behavior and the legacy invocation remain unchanged.

## Verification

- Run the ARC-001 libraries checks.
- Run controlled `delete --dry-run` and `prune --dry-run` checks.
- Run `node --check` and `git diff --check`.
