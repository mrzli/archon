# Archon CLI test reliability tasks

Status: completed and archived

Completed: 2026-09-06

Source: [Archon CLI test reliability](./spec.md)

All six tasks below are complete, each in a separate commit. This index and the
source specification remain the archived implementation and requirements record.

Keep CLI behavior unchanged. Use temporary installation targets and Git
repositories, fake tmux, and bounded terminal subprocesses. Never execute full
workstation setup as a test or add one-time migrations to setup. Preserve
unrelated working-tree changes.

## Implementation tasks

### [ACT-001: Check every Bash script](./tasks/ACT-001-bash-syntax-checks.md)

Depends on: none

Make the canonical runner validate every intended Bash script and fail on any syntax error.

Verify: Exercise the production syntax-check loop with valid and invalid temporary inputs.

### [ACT-002: Isolate workspace adapter cases](./tasks/ACT-002-workspace-fixture-isolation.md)

Depends on: ACT-001

Make non-interactive workspace tests independent of the invoking terminal and other test cases.

Verify: Run adapter cases independently and together, with and without a terminal.

### [ACT-003: Verify automatic attachment through a terminal](./tasks/ACT-003-workspace-terminal-coverage.md)

Depends on: ACT-002

Test real CLI terminal detection and attachment wiring using a pseudo-terminal and fake tmux.

Verify: Run focused terminal and non-terminal cases with fresh fixtures.

### [ACT-004: Test shared production installation operations](./tasks/ACT-004-shared-installation.md)

Depends on: ACT-003

Make setup and installation tests use the same narrowly scoped copying and managed-library replacement implementation.

Verify: Run installation tests using temporary destinations, including repeat-install, stale-module, and preservation cases.

### [ACT-005: Isolate real Git test operations](./tasks/ACT-005-git-environment-isolation.md)

Depends on: ACT-004

Make real Git tests independent of personal Git configuration and inherited repository settings.

Verify: Run repository-status and synchronization tests under normal and synthetic conflicting environments.

### [ACT-006: Verify, document, and close the proposal](./tasks/ACT-006-verify-document-close.md)

Depends on: ACT-001 through ACT-005

Record complete evidence for the specification and move enduring guidance into maintained documentation.

Verify: Audit every acceptance case in the source spec against test coverage or recorded focused verification.

## Completion criteria

- Terminal and non-terminal suite runs pass with independent workspace fixtures.
- Every intended Bash script is checked, including failure on a later invalid file.
- Layout tests exercise production installation and replacement operations.
- Real Git tests are insulated from personal configuration and inherited overrides.
- Durable documentation and final verification records are complete.

## Final verification

Terminal and non-terminal runs of the canonical suite passed. The workspace
adapter passed all six cases; installation and migration checks passed two
cases each. The Git isolation regression passed with synthetic external signing,
hook, index, and repository settings. Individual Bash and Node syntax checks and
whitespace checks passed. ShellCheck was unavailable and explicitly skipped.
