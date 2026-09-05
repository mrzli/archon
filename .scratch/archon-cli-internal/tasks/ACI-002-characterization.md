# ACI-002: Strengthen domain characterization coverage

Status: completed

Completed: 2026-09-05

Area: Tests

Depends on: ACI-001

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Protect current projects and libraries domain behavior before moving that
behavior into smaller modules.

## Acceptance checklist

- [x] Cover current library manifest and scoped-package validation.
- [x] Cover dependencies, dev dependencies, optional dependencies, and peer
      dependencies.
- [x] Cover invalid local dependency protocols, missing paths, name mismatch,
      duplicate package names, and dependency cycles.
- [x] Cover dependency-first build ordering and missing build scripts.
- [x] Cover current Bun install/build arguments and failure propagation using a
      fake executable.
- [x] Cover projects GitHub command construction, response parsing, pagination,
      deduplication, and every externally reachable blacklist behavior using
      fake `gh` responses. Exhaustive tests for the currently empty repository
      blacklist follow its pure extraction in ACI-005.
- [x] Cover libraries GitHub response validation using fake `gh` responses.
- [x] Cover current local projects and libraries discovery rules.
- [x] Cover current clone destination conflicts and clone commands.
- [x] Preserve and assert current help, stream, and exit-status contracts.
- [x] Run only against temporary homes, repositories, and fake executables.
- [x] Make no production behavior change solely to accommodate the tests.

## Verification

- Run `tests/archon-cli/run.sh`.
- Confirm the new tests pass against the otherwise unchanged implementation.
- Confirm no test contacts real GitHub or mutates the real home or tmux server.
- Run `git diff --check`.

Completed with black-box projects and libraries characterization suites using
temporary homes and fake Git, GitHub CLI, and Bun executables. All 44 Node
tests and all 15 shell-suite checks pass. Node and Bash syntax checks and
`git diff --check` pass; ShellCheck is unavailable. Production CLI sources are
unchanged. The configured project repository blacklist is empty, so exhaustive
tests for its otherwise unreachable validation branches remain assigned to
ACI-005 after pure extraction.
