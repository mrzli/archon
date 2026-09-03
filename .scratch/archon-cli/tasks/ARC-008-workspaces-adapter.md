# ARC-008: Add a JavaScript workspace orchestrator over legacy launchers

Status: completed

Area: Workspaces

Depends on: ARC-005

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Introduce the new workspace command while delegating actual group work to the
existing Bash launchers.

## Acceptance checklist

- [x] Node parses aggregate invocations and the `--group`/`-g` option.
- [x] Every group initially delegates to its legacy launcher.
- [x] Aggregate routing can mix legacy and JavaScript groups later.
- [x] Hubs and attach/switch behavior are preserved temporarily.
- [x] Legacy launcher entry points remain functional.

## Verification

- Compare aggregate order, partial failures, attach/switch, and group results
  using the fake tmux harness.
- Run Node syntax checks and `git diff --check`.

## Verification evidence

Added an importable JavaScript workspace orchestrator and routed
`archon workspaces` to it. Named groups use `--group` or `-g`; aggregate calls
invoke each legacy launcher individually, allowing later mixed routing. Hubs,
group order, failure aggregation, and attach/switch behavior remain unchanged.
The workspace README documents this transitional interface.

The injected-runner test covers help and invalid calls, both group option
forms, aggregate start and stop ordering, partial failure, attach, and switch.
Two isolated integration tests exercised named and aggregate delegation through
the real root CLI, legacy launchers, and fake tmux. All seven root-command
tests, both installation-layout tests, and all seven unchanged legacy workspace
tests passed. Relevant Node and Bash syntax checks and `git diff --check`
passed; ShellCheck was unavailable.
