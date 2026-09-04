# ARC-021: Complete documentation and close the proposal

Status: proposed

Area: Documentation

Depends on: ARC-018, ARC-019, ARC-020

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Make durable documentation describe the final installed behavior and archive
the completed planning records.

## Acceptance checklist

- [ ] Archon's tool-local READMEs document the CLI, alias, fixed roots, installation paths, and workspace groups.
- [ ] The repository root README remains focused on workstation setup.
- [ ] Obsolete launcher instructions are removed from durable documentation.
- [ ] The one-time CLI migration and its ordering after setup are documented.
- [ ] Installed help and tool-local README usage agree.
- [ ] The specification and task records contain final verification evidence.
- [ ] The specification and task index are marked completed and archived in place.

## Verification

- Run the full focused CLI suite and all Node syntax checks.
- Run `bash -n` and ShellCheck when available on setup, migration, and test scripts.
- Run the dedicated migration suite.
- Run `git diff --check`.
