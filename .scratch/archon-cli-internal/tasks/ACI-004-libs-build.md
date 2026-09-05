# ACI-004: Extract libraries build logic

Status: completed

Completed: 2026-09-05

Area: Libraries architecture

Depends on: ACI-003

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Make library manifest, dependency graph, and build-order policy a cohesive,
independently tested domain unit while preserving command orchestration.

## Acceptance checklist

- [x] Extract manifest reading/validation only where it supports a coherent
      boundary between filesystem orchestration and pure policy.
- [x] Extract local dependency resolution and graph construction.
- [x] Extract duplicate-name and dependency-cycle detection.
- [x] Extract dependency-first build ordering and build-script validation.
- [x] Expose pure functions needed by focused tests without adding a CLI API.
- [x] Keep Bun invocation and user-facing build progress in the libraries
      command orchestration.
- [x] Preserve supported dependency fields and `file:` protocol rules.
- [x] Preserve frozen Bun installs, disabled lifecycle scripts, and one explicit
      build per package.
- [x] Preserve all graph and build output, ordering, errors, and exit statuses.
- [x] Avoid one-file-per-command fragmentation or a generic graph framework.

## Verification

- Run focused pure tests for graph validation, ordering, and cycles.
- Run build and graph integration contracts with temporary packages and fake
  Bun.
- Run `tests/archon-cli/run.sh`.
- Run `node --check` on changed modules.
- Run `git diff --check`.

Completed by moving package manifest loading, dependency validation, graph
construction, cycle detection, build ordering, and build-script validation to
one `libs/src/build.mjs` domain module. Bun execution and all CLI output remain
in `libs.mjs`. Four focused module tests cover canonical-path graph resolution,
dependency-first ordering, exact cycle errors, and build-script validation.
All 49 Node tests and all 15 shell-suite checks pass. Node and Bash syntax
checks and `git diff --check` pass; ShellCheck is unavailable.
