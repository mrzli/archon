# ARC-011: Convert the miscellaneous-projects workspace group

Status: completed

Area: Workspaces

Depends on: ARC-010

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Route the final retained workspace group to JavaScript, leaving only the
temporary hubs compatibility path in Bash.

## Acceptance checklist

- [x] The fixed project mapping is represented once in JavaScript.
- [x] Named and aggregate operations use the new implementation.
- [x] Existing shared workspace primitives are reused.
- [x] Hubs alone remain delegated to Bash.

## Verification

- Verify project mapping, missing directories, repeated start/stop, exact
  windows and commands, and injected failures.
- Run Node syntax checks and `git diff --check`.

Completed with dedicated Node tests, the workspace adapter and legacy launcher
regression suites, repository-level CLI and installation tests, Node syntax
checks, and `git diff --check`.
