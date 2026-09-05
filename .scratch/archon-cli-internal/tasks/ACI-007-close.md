# ACI-007: Audit and document the behavior-preserving checkpoint

Status: completed

Completed: 2026-09-05

Area: Verification and documentation

Depends on: ACI-006

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Confirm that the internal work improved testability and module ownership
without implementing any functional proposal item early.

## Acceptance checklist

- [x] Confirm no invocation-specific root remains in mutable module state.
- [x] Confirm extracted modules follow cohesive domain boundaries.
- [x] Confirm direct filesystem access and `runProcess()` remain simple.
- [x] Confirm no universal runtime context, service container, logger, generic
      GitHub client, or command framework was introduced.
- [x] Confirm all public commands, output streams, messages, exit statuses, and
      side effects remain unchanged.
- [x] Confirm missing-root behavior and partial workspace behavior were not
      changed by this proposal.
- [x] Confirm runtime installation still excludes tests and development files.
- [x] Confirm the migration remains repeat-safe.
- [x] Update contributor instructions with the canonical verification command.
- [x] Move enduring architectural guidance into the relevant `AGENTS.md` only
      where needed.
- [x] Mark this internal specification and task records completed and archived.
- [x] Leave the separate functional specification provisional and unchanged.

## Verification

- Run `tests/archon-cli/run.sh`.
- Run installation-layout and migration suites explicitly for final evidence.
- Run all Node and Bash syntax checks.
- Run ShellCheck when available.
- Run `git diff --check`.
- Record the final verification result in this task and the task index.

The final audit passed on 2026-09-05. No mutable invocation root, universal
runtime context, service container, logger, generic GitHub client, command
framework, or expanded subprocess abstraction was introduced. Filesystem and
terminal effects remain direct in orchestration modules, while the extracted
modules own only cohesive build or GitHub inventory policy. Public command and
side-effect contracts remain protected by characterization and integration
coverage; production workspace code and the functional specification were not
changed. Runtime installation includes the extracted modules while excluding
development files and tests, and the migration remains repeat-safe. All 59
Node tests and all 15 shell-suite checks passed, along with Node and Bash syntax
checks and `git diff --check`; ShellCheck was unavailable.
