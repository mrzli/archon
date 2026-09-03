# ARC-006: Route projects through a relocated copy

Status: proposed

Area: Projects

Depends on: ARC-005

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Provide `archon projects` using a minimally changed relocated implementation
while preserving the legacy command.

## Acceptance checklist

- [ ] The projects implementation is copied into its tool source directory.
- [ ] `archon projects` invokes it as a child Node process.
- [ ] Arguments, standard streams, signals where practical, and exit status propagate.
- [ ] No modularization or shared-code extraction is included.
- [ ] The legacy `projects.mjs` remains functional.

## Verification

- Compare old and new help, status, invalid calls, and controlled dry-runs.
- Run Node syntax checks and `git diff --check`.
