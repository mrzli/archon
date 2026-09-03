# ARC-002: Decouple the projects target from script location

Status: proposed

Area: Projects

Depends on: ARC-001

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Make the legacy projects command operate on the fixed personal-project root so
it can later move without changing its target.

## Acceptance checklist

- [ ] The target resolves to `~/projects/personal` independently of script location.
- [ ] Tests can inject a temporary home/root without affecting production defaults.
- [ ] Deletion safety checks the exact resolved root rather than its basename.
- [ ] All other command behavior and the legacy invocation remain unchanged.

## Verification

- Run the ARC-001 projects checks.
- Run controlled `delete --dry-run` and `prune --dry-run` checks.
- Run `node --check` and `git diff --check`.
