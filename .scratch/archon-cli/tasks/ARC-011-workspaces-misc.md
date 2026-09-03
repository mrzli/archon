# ARC-011: Convert the miscellaneous-projects workspace group

Status: proposed

Area: Workspaces

Depends on: ARC-010

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Route the final retained workspace group to JavaScript, leaving only the
temporary hubs compatibility path in Bash.

## Acceptance checklist

- [ ] The fixed project mapping is represented once in JavaScript.
- [ ] Named and aggregate operations use the new implementation.
- [ ] Existing shared workspace primitives are reused.
- [ ] Hubs alone remain delegated to Bash.

## Verification

- Verify project mapping, missing directories, repeated start/stop, exact
  windows and commands, and injected failures.
- Run Node syntax checks and `git diff --check`.
