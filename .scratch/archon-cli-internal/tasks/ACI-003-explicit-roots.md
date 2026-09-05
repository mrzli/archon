# ACI-003: Replace mutable root globals

Status: completed

Completed: 2026-09-05

Area: Projects and libraries architecture

Depends on: ACI-002

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Make projects and libraries invocation paths explicit without introducing a
general dependency-injection design or changing command behavior.

## Acceptance checklist

- [x] Remove mutable `ROOT_DIR` and `REQUIRED_ROOT_DIR` module variables from
      projects.
- [x] Remove mutable `ROOT_DIR` and `REQUIRED_ROOT_DIR` module variables from
      libraries.
- [x] Derive both roots locally for every `main(arguments, context)` call.
- [x] Pass paths to handlers or narrowly scoped closures that need them.
- [x] Do not pass root state into pure helpers that do not need it.
- [x] Preserve support for temporary `homeDir` and `rootDir` test contexts.
- [x] Demonstrate that invocations with distinct roots cannot overwrite one
      another's state.
- [x] Preserve current missing-root failures, output, streams, exit statuses,
      and side effects.
- [x] Do not introduce a runtime service container or class hierarchy.

## Verification

- Run focused direct-module tests using multiple temporary roots.
- Compare root CLI and direct-module command contracts before and after.
- Run `tests/archon-cli/run.sh`.
- Run `node --check` on changed modules.
- Run `git diff --check`.

Completed by deriving a two-value `{ requiredRootDir, rootDir }` paths object in
each domain `main()` invocation and passing only the required path values to
command handlers and local-discovery closures. A direct-module regression
covers repeated projects and libraries invocations with distinct roots. All 45
Node tests and all 15 shell-suite checks pass. Node and Bash syntax checks and
`git diff --check` pass; ShellCheck is unavailable.
