# Archon CLI functional improvement tasks

Status: pending

Source: [Archon CLI functional improvements](./spec.md)

These tasks implement only the required functional baseline. The optional
workspace-status and synchronization-planning ideas remain deferred for later
specifications.

Every checkpoint must preserve destructive-operation safeguards, continue
processing independent targets after individual failures, and pass the
canonical focused CLI suite without contacting the real home directory,
GitHub account, or tmux server.

## Phase 1: Make workspace creation recoverable

### [ACF-001: Roll back partially created workspace sessions](./tasks/ACF-001-workspace-rollback.md)

- Make session creation failure-atomic after `tmux new-session` succeeds.
- Kill only a session created by the current invocation when later setup fails.
- Preserve the original failure, report cleanup failure, and allow a clean
  retry.
- Keep processing later sessions and workspace groups after a failure.

Verify: isolated fake-tmux tests cover every setup stage, cleanup outcomes,
retry, pre-existing sessions, and continued group processing.

## Phase 2: Support absent managed roots

### [ACF-002: Define missing-root behavior for projects](./tasks/ACF-002-projects-missing-root.md)

- Make projects status, delete, and prune treat an absent root as an empty
  local state without creating it.
- Make projects sync create its root recursively and continue normally.
- Preserve operational errors for unreadable paths and non-directories.

Verify: focused tests assert messages, statuses, filesystem side effects, and
the absence of unintended Git, GitHub, or removal calls.

### [ACF-003: Define missing-root behavior for libraries](./tasks/ACF-003-libs-missing-root.md)

- Make libraries status, delete, prune, graph, and build treat an absent root
  as an empty local state without creating it.
- Make libraries sync create its root recursively and continue normally.
- Preserve operational errors for unreadable paths and non-directories.

Verify: focused tests assert messages, statuses, filesystem side effects, and
the absence of unintended Git, GitHub, Bun, or removal calls.

## Phase 3: Standardize command statuses

### [ACF-004: Standardize usage-error exit statuses](./tasks/ACF-004-exit-statuses.md)

- Return `2` for invalid syntax and unsupported options at every dispatcher.
- Keep help at `0` and operational failures at `1`.
- Update integration coverage for projects and libraries where usage failures
  currently return `1`.

Verify: root, projects, libraries, and workspaces status-contract tests pass
for help, usage failures, and representative operational failures.

## Phase 4: Document and close the proposal

### [ACF-005: Document final behavior and close the proposal](./tasks/ACF-005-document-and-close.md)

- Document exit statuses and missing-root behavior in the tool-local READMEs.
- Audit rollback, safeguards, installation filtering, and repeat-safe
  migration/setup behavior.
- Record final verification and archive the completed planning records.

Verify: the canonical CLI suite, installation and migration checks, Node and
Bash syntax checks, optional ShellCheck, and `git diff --check` pass.

## Success criteria

- Partial workspace setup does not leave a managed session that blocks retry.
- Every projects and libraries command has tested absent-root behavior, and
  only sync creates the missing root.
- Help succeeds, usage errors return `2`, and operational failures return `1`.
- Existing deletion and prune safeguards remain intact.
- Runtime installation and provisioning remain repeat-safe.
