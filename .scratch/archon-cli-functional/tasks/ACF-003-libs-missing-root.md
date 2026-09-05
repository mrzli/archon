# ACF-003: Define missing-root behavior for libraries

Status: pending

Area: Libraries

Depends on: ACF-002

Source: [Archon CLI functional improvement tasks](../tasks.md)

## Outcome

Treat an absent libraries root as a normal empty or bootstrap state while
retaining operational failures for invalid or inaccessible existing paths.

## Acceptance checklist

- [ ] Add isolated tests that reproduce every libraries command's current
      absent-root behavior before changing it.
- [ ] `libs status` reports that no local repositories exist and returns `0`
      without creating the root.
- [ ] `libs delete` reports that no local repositories exist and returns `0`
      without prompting, removing anything, or creating the root.
- [ ] `libs prune` reports that no obsolete local repositories exist and
      returns `0` without removing anything or creating the root.
- [ ] If prune obtains remote inventory before checking local state, preserve
      its safety ordering and use only fake GitHub responses in tests.
- [ ] `libs graph` and `libs build` report that no local repositories exist and
      return `0` without creating the root or invoking Bun.
- [ ] `libs sync` recursively creates the root when absent, then continues
      remote inventory and cloning normally.
- [ ] Root creation is repeat-safe and does not duplicate or drift state.
- [ ] A root path that exists but is not a directory remains an operational
      error.
- [ ] An existing root that cannot be read remains an operational error.
- [ ] Tests assert concise output, exit status, root presence or absence, and
      the absence of unintended Git, GitHub, Bun, or removal operations.
- [ ] Preserve build, graph, discovery, synchronization, prune, deletion,
      confirmation, and inventory-revalidation behavior for an existing root.
- [ ] Run the complete canonical CLI suite at this checkpoint.

## Verification

- Run focused libraries tests with temporary homes, missing roots, invalid
  root paths, fake GitHub responses, and fake Git/Bun subprocesses.
- Verify a missing-root sync can clone into the newly created libraries root.
- Run `tests/archon-cli/run.sh`.
- Run `git diff --check`.
