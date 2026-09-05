# ACI-003: Replace mutable root globals

Status: pending

Area: Projects and libraries architecture

Depends on: ACI-002

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Make projects and libraries invocation paths explicit without introducing a
general dependency-injection design or changing command behavior.

## Acceptance checklist

- [ ] Remove mutable `ROOT_DIR` and `REQUIRED_ROOT_DIR` module variables from
      projects.
- [ ] Remove mutable `ROOT_DIR` and `REQUIRED_ROOT_DIR` module variables from
      libraries.
- [ ] Derive both roots locally for every `main(arguments, context)` call.
- [ ] Pass paths to handlers or narrowly scoped closures that need them.
- [ ] Do not pass root state into pure helpers that do not need it.
- [ ] Preserve support for temporary `homeDir` and `rootDir` test contexts.
- [ ] Demonstrate that invocations with distinct roots cannot overwrite one
      another's state.
- [ ] Preserve current missing-root failures, output, streams, exit statuses,
      and side effects.
- [ ] Do not introduce a runtime service container or class hierarchy.

## Verification

- Run focused direct-module tests using multiple temporary roots.
- Compare root CLI and direct-module command contracts before and after.
- Run `tests/archon-cli/run.sh`.
- Run `node --check` on changed modules.
- Run `git diff --check`.
