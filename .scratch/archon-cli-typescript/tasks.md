# Archon CLI Bun and TypeScript tasks

Status: planned

Created: 2026-09-06

Source: [Migration spec](./spec.md)

Execute these seven checkpoints sequentially. Each must leave the CLI working.
Task files contain acceptance criteria and a place for actual completion evidence.

| Order | Task | Depends on | Status |
| --- | --- | --- | --- |
| 1 | [ACTS-001: Switch JavaScript execution to Bun](./tasks/ACTS-001-bun-runtime.md) | none | Planned |
| 2 | [ACTS-002: Introduce strict compilation and checked builds](./tasks/ACTS-002-typescript-foundation.md) | ACTS-001 | Planned |
| 3 | [ACTS-003: Convert shared modules and test helpers](./tasks/ACTS-003-shared-types.md) | ACTS-002 | Planned |
| 4 | [ACTS-004: Convert libraries command and tests](./tasks/ACTS-004-libs-types.md) | ACTS-003 | Planned |
| 5 | [ACTS-005: Convert projects command and tests](./tasks/ACTS-005-projects-types.md) | ACTS-004 | Planned |
| 6 | [ACTS-006: Convert workspaces command and tests](./tasks/ACTS-006-workspaces-types.md) | ACTS-005 | Planned |
| 7 | [ACTS-007: Finish TypeScript conversion and verify deployment](./tasks/ACTS-007-finish-verify.md) | ACTS-006 | Planned |

## Shared checkpoint checks

- Read applicable AGENTS.md instructions and the specification before editing.
- Run focused behavioral tests, the complete component suite, and root build/install
  integration checks. Include terminal stdin and `/dev/null` variants of the
  complete root runner at each checkpoint.
- From ACTS-002 onward run strict typecheck and the checked JavaScript-emitting
  build. Test discovery must include both legacy and converted tests during migration.
- Use temporary homes, local Git fixtures, and fake external commands. Never run
  full setup or operate on real accounts, projects, or tmux sessions for tests.
- For setup changes run `bash -n setup.sh`; validate changed Bash files individually.
  Run ShellCheck when available and `git diff --check`; record unavailable tools.
- Preserve existing behavior. Add focused coverage only for consequential migration
  risks, such as runtime compatibility, compilation failure, or artifact leakage.
- Keep task records current; record evidence before marking tasks complete.

## Final completion

The final checkpoint moves enduring operational knowledge into current docs and
usage READMEs, then closes this planning record. Node provisioning for unrelated
workstation tools and removal of legacy installed files are outside this plan.
