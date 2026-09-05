# ACF-002: Define missing-root behavior for projects

Status: completed

Completed: 2026-09-05

Area: Projects

Depends on: ACF-001

Source: [Archon CLI functional improvement tasks](../tasks.md)

## Outcome

Treat an absent projects root as a normal empty or bootstrap state while
retaining operational failures for invalid or inaccessible existing paths.

## Acceptance checklist

- [x] Add isolated tests that reproduce every projects command's current
      absent-root behavior before changing it.
- [x] `projects status` reports that no local repositories exist and returns
      `0` without creating the root.
- [x] `projects delete` reports that no local repositories exist and returns
      `0` without prompting, removing anything, or creating the root.
- [x] `projects prune` reports that no obsolete local repositories exist and
      returns `0` without removing anything or creating the root.
- [x] If prune obtains remote inventory before checking local state, preserve
      its safety ordering and use only fake GitHub responses in tests.
- [x] `projects sync` recursively creates the root when absent, then continues
      remote inventory and cloning normally.
- [x] Root creation is repeat-safe and does not duplicate or drift state.
- [x] A root path that exists but is not a directory remains an operational
      error.
- [x] An existing root that cannot be read remains an operational error.
- [x] Tests assert concise output, exit status, root presence or absence, and
      the absence of unintended Git, GitHub, or removal operations.
- [x] Preserve discovery, synchronization, prune, deletion, confirmation, and
      inventory-revalidation behavior for an existing projects root.
- [x] Run the complete canonical CLI suite at this checkpoint.

## Verification

- Run focused projects tests with temporary homes, missing roots, invalid root
  paths, fake GitHub responses, and fake subprocesses.
- Verify a missing-root sync can clone into the newly created owner directory.
- Run `tests/archon-cli/run.sh`.
- Run `git diff --check`.

Completed with temporary-home coverage for missing, non-directory, and
unreadable roots. Status and delete perform no external operations, prune
retains remote inventory acquisition, and sync creates the root and invokes the
expected clone. The canonical suite passed all 72 Node tests and 13 shell-suite
checks, plus Node and Bash syntax checks and `git diff --check`. ShellCheck was
unavailable and reported as skipped.
