# ACF-002: Define missing-root behavior for projects

Status: pending

Area: Projects

Depends on: ACF-001

Source: [Archon CLI functional improvement tasks](../tasks.md)

## Outcome

Treat an absent projects root as a normal empty or bootstrap state while
retaining operational failures for invalid or inaccessible existing paths.

## Acceptance checklist

- [ ] Add isolated tests that reproduce every projects command's current
      absent-root behavior before changing it.
- [ ] `projects status` reports that no local repositories exist and returns
      `0` without creating the root.
- [ ] `projects delete` reports that no local repositories exist and returns
      `0` without prompting, removing anything, or creating the root.
- [ ] `projects prune` reports that no obsolete local repositories exist and
      returns `0` without removing anything or creating the root.
- [ ] If prune obtains remote inventory before checking local state, preserve
      its safety ordering and use only fake GitHub responses in tests.
- [ ] `projects sync` recursively creates the root when absent, then continues
      remote inventory and cloning normally.
- [ ] Root creation is repeat-safe and does not duplicate or drift state.
- [ ] A root path that exists but is not a directory remains an operational
      error.
- [ ] An existing root that cannot be read remains an operational error.
- [ ] Tests assert concise output, exit status, root presence or absence, and
      the absence of unintended Git, GitHub, or removal operations.
- [ ] Preserve discovery, synchronization, prune, deletion, confirmation, and
      inventory-revalidation behavior for an existing projects root.
- [ ] Run the complete canonical CLI suite at this checkpoint.

## Verification

- Run focused projects tests with temporary homes, missing roots, invalid root
  paths, fake GitHub responses, and fake subprocesses.
- Verify a missing-root sync can clone into the newly created owner directory.
- Run `tests/archon-cli/run.sh`.
- Run `git diff --check`.
