# Archon CLI internal improvement tasks

Status: completed and archived

Completed: 2026-09-05

This index and its task files are retained as the archived implementation and
verification record. The separate functional proposal remains provisional.

Source: [Archon CLI internal architecture improvements](./spec.md)

These tasks create a behavior-preserving checkpoint before the separate
functional proposal is implemented. Every task must keep the existing command
surface, output, exit statuses, and side effects unchanged.

## Phase 1: Protect current behavior

### [ACI-001: Add the canonical CLI verification runner](./tasks/ACI-001-test-runner.md)

- Add one safe entry point for every focused Node and shell suite.
- Include syntax, optional ShellCheck, and diff validation.
- Document the canonical command for contributors.

Verify: the runner executes every existing suite without contacting the real
home, GitHub account, tmux server, or setup entry point.

### [ACI-002: Strengthen domain characterization coverage](./tasks/ACI-002-characterization.md)

- Cover current library build, graph, manifest, dependency, and Bun behavior.
- Cover current projects and libraries GitHub inventory behavior.
- Cover local discovery, clone conflicts, help, streams, and exit statuses.

Verify: new tests pass against the unchanged implementation and use only
temporary roots and fake executables.

## Phase 2: Remove hidden invocation state

### [ACI-003: Replace mutable root globals](./tasks/ACI-003-explicit-roots.md)

- Derive projects and libraries roots per `main()` invocation.
- Pass only required path values to effectful handlers.
- Do not introduce a universal runtime context.

Verify: all existing behavior remains identical and invocations using distinct
temporary roots cannot affect one another.

## Phase 3: Extract cohesive domain logic

### [ACI-004: Extract libraries build logic](./tasks/ACI-004-libs-build.md)

- Move manifest validation, dependency resolution, graph construction, cycle
  detection, and ordering into one cohesive domain module.
- Keep Bun execution and CLI output behavior unchanged.

Verify: focused pure tests and existing build/graph command contracts pass.

### [ACI-005: Extract projects GitHub inventory logic](./tasks/ACI-005-projects-github.md)

- Isolate GitHub response parsing and blacklist validation.
- Keep GitHub command execution and projects policy unchanged.

Verify: focused pure tests and all remote, sync, and prune contracts pass.

### [ACI-006: Extract libraries GitHub inventory logic](./tasks/ACI-006-libs-github.md)

- Isolate GitHub response validation and normalization.
- Keep GitHub command execution, clone behavior, and library policy unchanged.

Verify: focused pure tests and all remote, sync, and prune contracts pass.

## Phase 4: Close the internal proposal

### [ACI-007: Audit and document the behavior-preserving checkpoint](./tasks/ACI-007-close.md)

- Confirm that no functional proposal item was implemented early.
- Update contributor guidance and archive the completed internal records.
- Run the complete canonical suite and installation/migration checks.

Verify: the full audit passes and durable user-facing command documentation
does not claim any unimplemented functional behavior.

## Final verification

The completed checkpoint passed all 59 Node tests and all 15 shell-suite checks
on 2026-09-05. The installation-layout and migration suites also passed when
run explicitly. Node and Bash syntax checks and `git diff --check` passed;
ShellCheck was unavailable. The functional proposal remains provisional and
unchanged.
