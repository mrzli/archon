# ACF-005: Document final behavior and close the proposal

Status: pending

Area: Documentation and verification

Depends on: ACF-004

Source: [Archon CLI functional improvement tasks](../tasks.md)

## Outcome

Make durable CLI documentation match the implemented functional behavior,
complete the final safety audit, and archive the planning records.

## Acceptance checklist

- [ ] Document exit statuses `0`, `1`, and `2` in the root Archon CLI README.
- [ ] Document projects missing-root behavior in the projects README.
- [ ] Document libraries missing-root behavior in the libraries README.
- [ ] Document workspace rollback only if it provides useful operational
      guidance; do not expose unnecessary cleanup internals.
- [ ] Confirm command help and durable documentation match implemented
      behavior.
- [ ] Confirm partial workspace failures can be retried successfully.
- [ ] Confirm only sync creates absent projects or libraries roots.
- [ ] Confirm destructive confirmations, cleanliness checks, dry runs, and
      remote-inventory revalidation remain intact.
- [ ] Confirm failures do not prevent processing of remaining independent
      repositories, sessions, or groups.
- [ ] Confirm runtime installation excludes tests, READMEs, and contributor
      instructions.
- [ ] Confirm the dedicated Archon CLI migration and setup operations remain
      repeat-safe.
- [ ] Move all enduring operational knowledge into tool-local READMEs.
- [ ] Record final verification evidence in this task and the task index.
- [ ] Mark the specification and task records completed and archived.
- [ ] Leave optional workspace-status and synchronization-planning ideas
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
