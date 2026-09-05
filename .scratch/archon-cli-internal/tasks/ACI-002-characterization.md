# ACI-002: Strengthen domain characterization coverage

Status: pending

Area: Tests

Depends on: ACI-001

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Protect current projects and libraries domain behavior before moving that
behavior into smaller modules.

## Acceptance checklist

- [ ] Cover current library manifest and scoped-package validation.
- [ ] Cover dependencies, dev dependencies, optional dependencies, and peer
      dependencies.
- [ ] Cover invalid local dependency protocols, missing paths, name mismatch,
      duplicate package names, and dependency cycles.
- [ ] Cover dependency-first build ordering and missing build scripts.
- [ ] Cover current Bun install/build arguments and failure propagation using a
      fake executable.
- [ ] Cover projects GitHub command construction, response parsing, pagination,
      deduplication, and blacklist validation using fake `gh` responses.
- [ ] Cover libraries GitHub response validation using fake `gh` responses.
- [ ] Cover current local projects and libraries discovery rules.
- [ ] Cover current clone destination conflicts and clone commands.
- [ ] Preserve and assert current help, stream, and exit-status contracts.
- [ ] Run only against temporary homes, repositories, and fake executables.
- [ ] Make no production behavior change solely to accommodate the tests.

## Verification

- Run `tests/archon-cli/run.sh`.
- Confirm the new tests pass against the otherwise unchanged implementation.
- Confirm no test contacts real GitHub or mutates the real home or tmux server.
- Run `git diff --check`.
