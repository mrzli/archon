# ACI-004: Extract libraries build logic

Status: pending

Area: Libraries architecture

Depends on: ACI-003

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Make library manifest, dependency graph, and build-order policy a cohesive,
independently tested domain unit while preserving command orchestration.

## Acceptance checklist

- [ ] Extract manifest reading/validation only where it supports a coherent
      boundary between filesystem orchestration and pure policy.
- [ ] Extract local dependency resolution and graph construction.
- [ ] Extract duplicate-name and dependency-cycle detection.
- [ ] Extract dependency-first build ordering and build-script validation.
- [ ] Expose pure functions needed by focused tests without adding a CLI API.
- [ ] Keep Bun invocation and user-facing build progress in the libraries
      command orchestration.
- [ ] Preserve supported dependency fields and `file:` protocol rules.
- [ ] Preserve frozen Bun installs, disabled lifecycle scripts, and one explicit
      build per package.
- [ ] Preserve all graph and build output, ordering, errors, and exit statuses.
- [ ] Avoid one-file-per-command fragmentation or a generic graph framework.

## Verification

- Run focused pure tests for graph validation, ordering, and cycles.
- Run build and graph integration contracts with temporary packages and fake
  Bun.
- Run `tests/archon-cli/run.sh`.
- Run `node --check` on changed modules.
- Run `git diff --check`.
