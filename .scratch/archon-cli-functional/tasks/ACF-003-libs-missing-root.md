# ACF-003: Define missing-root behavior for libraries

Status: completed

Completed: 2026-09-05

Area: Libraries

Depends on: ACF-002

Source: [Archon CLI functional improvement tasks](../tasks.md)

## Outcome

Treat an absent libraries root as a normal empty or bootstrap state while
retaining operational failures for invalid or inaccessible existing paths.

## Acceptance checklist

- [x] Add isolated tests that reproduce every libraries command's current
      absent-root behavior before changing it.
- [x] `libs status` reports that no local repositories exist and returns `0`
      without creating the root.
- [x] `libs delete` reports that no local repositories exist and returns `0`
      without prompting, removing anything, or creating the root.
- [x] `libs prune` reports that no obsolete local repositories exist and
      returns `0` without removing anything or creating the root.
- [x] If prune obtains remote inventory before checking local state, preserve
      its safety ordering and use only fake GitHub responses in tests.
- [x] `libs graph` and `libs build` report that no local repositories exist and
      return `0` without creating the root or invoking Bun.
- [x] `libs sync` recursively creates the root when absent, then continues
      remote inventory and cloning normally.
- [x] Root creation is repeat-safe and does not duplicate or drift state.
- [x] A root path that exists but is not a directory remains an operational
      error.
- [x] An existing root that cannot be read remains an operational error.
- [x] Tests assert concise output, exit status, root presence or absence, and
      the absence of unintended Git, GitHub, Bun, or removal operations.
- [x] Preserve build, graph, discovery, synchronization, prune, deletion,
      confirmation, and inventory-revalidation behavior for an existing root.
- [x] Run the complete canonical CLI suite at this checkpoint.

## Verification

- Run focused libraries tests with temporary homes, missing roots, invalid
  root paths, fake GitHub responses, and fake Git/Bun subprocesses.
- Verify a missing-root sync can clone into the newly created libraries root.
- Run `tests/archon-cli/run.sh`.
- Run `git diff --check`.

Completed with temporary-home coverage for all six missing-root command
categories plus non-directory and unreadable roots. Build and graph avoid Bun,
prune retains remote inventory acquisition, and sync creates the root and runs
the expected GitHub clone. The canonical suite passed all 81 Node tests and 15
shell-suite checks, plus Node and Bash syntax checks and `git diff --check`.
ShellCheck was unavailable and reported as skipped.
