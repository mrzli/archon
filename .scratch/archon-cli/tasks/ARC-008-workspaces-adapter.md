# ARC-008: Add a JavaScript workspace orchestrator over legacy launchers

Status: proposed

Area: Workspaces

Depends on: ARC-005

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Introduce the new workspace command while delegating actual group work to the
existing Bash launchers.

## Acceptance checklist

- [ ] Node parses aggregate invocations and the `--group`/`-g` option.
- [ ] Every group initially delegates to its legacy launcher.
- [ ] Aggregate routing can mix legacy and JavaScript groups later.
- [ ] Hubs and attach/switch behavior are preserved temporarily.
- [ ] Legacy launcher entry points remain functional.

## Verification

- Compare aggregate order, partial failures, attach/switch, and group results
  using the fake tmux harness.
- Run Node syntax checks and `git diff --check`.
