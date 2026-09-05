# ACF-005: Document final behavior and close the proposal

Status: completed

Completed: 2026-09-05

Area: Documentation and verification

Depends on: ACF-004

Source: [Archon CLI functional improvement tasks](../tasks.md)

## Outcome

Make durable CLI documentation match the implemented functional behavior,
complete the final safety audit, and archive the planning records.

## Acceptance checklist

- [x] Document exit statuses `0`, `1`, and `2` in the root Archon CLI README.
- [x] Document projects missing-root behavior in the projects README.
- [x] Document libraries missing-root behavior in the libraries README.
- [x] Document workspace rollback only if it provides useful operational
      guidance; do not expose unnecessary cleanup internals.
- [x] Confirm command help and durable documentation match implemented
      behavior.
- [x] Confirm partial workspace failures can be retried successfully.
- [x] Confirm only sync creates absent projects or libraries roots.
- [x] Confirm destructive confirmations, cleanliness checks, dry runs, and
      remote-inventory revalidation remain intact.
- [x] Confirm failures do not prevent processing of remaining independent
      repositories, sessions, or groups.
- [x] Confirm runtime installation excludes tests, READMEs, and contributor
      instructions.
- [x] Confirm the dedicated Archon CLI migration and setup operations remain
      repeat-safe.
- [x] Move all enduring operational knowledge into tool-local READMEs.
- [x] Record final verification evidence in this task and the task index.
- [x] Mark the specification and task records completed and archived.
- [x] Leave optional workspace-status and synchronization-planning ideas
      deferred rather than implementing them as part of closure.

## Verification

- Run `tests/archon-cli/run.sh`.
- Run installation-layout and migration suites explicitly if final evidence
  needs to distinguish them from the aggregate runner.
- Run `node --check` on every changed executable and `.mjs` file.
- Run `bash -n` on every changed Bash script, including `setup.sh` when
  applicable.
- Run ShellCheck when available.
- Run `git diff --check`.
- Do not execute the complete setup script against the real home directory or
  contact the user's real GitHub account or tmux server.

Completed with durable documentation for exit statuses, missing managed roots,
and recoverable workspace startup. The final audit confirmed destructive
safeguards, continued processing after individual failures, runtime-only
installation, and repeat-safe migration/setup behavior. The canonical suite
passed all 112 Node tests and 15 shell-suite checks, plus Node and Bash syntax
checks and `git diff --check`. ShellCheck was unavailable and reported as
skipped.
