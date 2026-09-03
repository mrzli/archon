# ARC-021: Complete documentation and close the proposal

Status: proposed

Area: Documentation

Depends on: ARC-018, ARC-019, ARC-020

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Make durable documentation describe the final installed behavior and archive
the completed planning records.

## Acceptance checklist

- [ ] The root README documents the CLI, alias, fixed roots, installation paths, and workspace groups.
- [ ] Obsolete launcher instructions are removed from durable documentation.
- [ ] Installed help and README usage agree.
- [ ] The specification and task records contain final verification evidence.
- [ ] The specification and task index are marked completed and archived in place.

## Verification

- Run the full focused CLI suite and all Node syntax checks.
- Run `bash -n setup.sh` and ShellCheck when available.
- Run `git diff --check`.
