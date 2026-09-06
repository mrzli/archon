# Archon CLI simplification tasks

Status: partially implemented; ACS-001 completed, remaining tasks pending

Source: [Simplification spec](./spec.md)

Tasks are ordered from the smallest extraction to broader workspace changes,
followed by final verification. Creating these tasks does not start implementation.
Each task must leave the CLI working and preserve existing behavior. Do not add
classes, a general service container, or a mocking framework.

| Order | Task | Scope | Status |
| --- | --- | --- | --- |
| 1 | [ACS-001: Share argument helpers](./tasks/ACS-001-argument-helpers.md) | Identical small helpers | Completed (uncommitted) |
| 2 | [ACS-002: Share status orchestration](./tasks/ACS-002-status-workflow.md) | Projects and libraries status | Pending |
| 3 | [ACS-003: Share editor-session lifecycle](./tasks/ACS-003-workspace-lifecycle.md) | Repeated workspace management | Pending |
| 4 | [ACS-004: Introduce tmux operations object](./tasks/ACS-004-tmux-object.md) | Focused dependency boundary and simpler fakes | Pending |
| 5 | [ACS-005: Verify and document](./tasks/ACS-005-verify-close.md) | Final behavior and simplification audit | Pending |

## Working rules

- Read applicable component instructions before implementation.
- Reuse existing behavioral coverage; add a test only for a consequential gap
  exposed by the change. Do not create tests of trivial forwarding helpers.
- Run focused checks per task, plus the component and installation integration
  checks required by component instructions. Record actual results in the task.
- Run `node --check` on changed executable and `.mjs` files and
  `git diff --check` at each checkpoint.
- Use temporary homes and fake commands; never execute full setup or affect
  real repositories, GitHub services, or tmux sessions during verification.
- Preserve useful closures, domain-specific policy, and destructive safeguards.

## Deferred candidates

Remote-output formatting and separation of build loading from graph calculation
remain optional future work. Do not include them in these tasks without a
separate decision that they provide a concrete simplification.
