# ARC-007: Route libraries through a relocated copy

Status: proposed

Area: Libraries

Depends on: ARC-005

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Provide `archon libs` using a minimally changed relocated implementation while
preserving the legacy command.

## Acceptance checklist

- [ ] The libraries implementation is copied into its tool source directory.
- [ ] `archon libs` invokes it as a child Node process.
- [ ] Arguments, standard streams, signals where practical, and exit status propagate.
- [ ] No modularization or shared-code extraction is included.
- [ ] The legacy `libs.mjs` remains functional.

## Verification

- Compare old and new help, status, graph, invalid calls, and controlled dry-runs.
- Run Node syntax checks and `git diff --check`.
