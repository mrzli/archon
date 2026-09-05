# Archon CLI internal architecture improvements

Status: completed and archived

Completed: 2026-09-05

The behavior-preserving implementation and isolated verification are complete.
Durable verification and module-ownership guidance is kept with the Archon
sources; this specification is retained as the archived architecture record.

## Context

Archon CLI is a dependency-free Node.js command for personal repositories,
JavaScript libraries, and tmux workspaces. Its overall architecture fits that
small, fixed-purpose scope, but two implementation details make safe changes
harder than necessary:

- Projects and libraries store invocation-specific roots in mutable module
  globals.
- Cohesive domain logic is embedded in two large command modules and lacks
  focused tests.

The focused test suites also have no single canonical entry point.

This specification addresses those issues without changing public behavior.
Functional improvements are specified separately in
[`../archon-cli-functional/spec.md`](../archon-cli-functional/spec.md).

## Behavior-preservation contract

This work must not intentionally change:

- public commands, arguments, options, help, or output;
- standard-output and standard-error routing;
- exit statuses;
- missing-root behavior;
- repository discovery, GitHub inventory, status, synchronization, build,
  graph, prune, or deletion semantics;
- destructive confirmations and remote-inventory revalidation;
- tmux behavior;
- installation layout or runtime dependencies.

Tests added before a refactor must characterize current behavior, including
behavior that the functional specification later changes.

## Goals

- Provide one canonical command for the complete focused CLI test suite.
- Add characterization coverage for under-tested domain behavior.
- Remove invocation-specific mutable module state.
- Extract cohesive, testable domain logic from projects and libraries.
- Finish with a verified behavior-preserving checkpoint before functional
  work begins.

## Non-goals

- Fixing partial tmux workspace creation.
- Changing behavior for absent repository roots.
- Changing usage-error exit statuses.
- Adding commands or options.
- Changing the projects and libraries overlap semantics.
- Injecting all infrastructure or introducing a runtime service container.
- Replacing direct filesystem access with a filesystem abstraction.
- Introducing a logging abstraction or rewriting console output plumbing.
- Creating separate Git, GitHub, Bun, and tmux service objects.
- Expanding the existing subprocess wrapper beyond a demonstrated need.
- A plugin system, dynamic command registry, npm dependency, TypeScript, class
  hierarchy, or build step.

## Design principles

### Explicit invocation paths

Projects and libraries must not store `ROOT_DIR` or `REQUIRED_ROOT_DIR` as
mutable module-level variables.

Each `main(arguments, context)` invocation must derive its paths locally and
pass the required path values to command handlers or narrowly scoped helper
factories. Supplying no context must preserve current production behavior.

A simple implementation is preferred:

```javascript
export async function main(arguments_, { homeDir = homedir() } = {}) {
  const requiredRootDir = resolve(homeDir, 'projects/personal');
  const rootDir = requiredRootDir;

  return runCommand(arguments_, { requiredRootDir, rootDir });
}
```

The exact parameter shape is implementation-defined. Do not pass a universal
context through pure functions or introduce a dependency-injection framework.

Tests must demonstrate that imported invocations with different temporary
homes or roots do not affect one another.

### Pure domain modules

Extract logic when doing so creates a cohesive, independently testable unit.
Initial candidates are:

- Libraries manifest parsing and validation.
- Local dependency resolution and graph construction.
- Dependency-first build ordering and cycle detection.
- Projects GitHub response parsing and blacklist validation.
- Libraries GitHub response validation.

Pure functions receive data and return data or throw domain errors. They must
not perform console output, filesystem access, or subprocess execution.

Effectful orchestration may remain in the domain entry modules when extraction
would only move a small amount of procedural code. Do not create one file per
command.

An illustrative layout is:

```text
projects/src/
├── projects.mjs
└── github-inventory.mjs

libs/src/
├── libs.mjs
├── build.mjs
└── github-inventory.mjs
```

Filenames are not requirements. Boundaries must follow behavior.

Projects and libraries must not share abstractions for unlike GitHub
inventory, layouts, cloning, or build policy. Existing shared repository
inspection, destructive workflows, and sync orchestration remain appropriate.

### Keep effect boundaries direct

Archon CLI has three broad operating-system boundaries: filesystem access,
terminal interaction, and subprocess execution.

- Continue using Node filesystem APIs directly and test them against temporary
  directories.
- Retain the existing small `runProcess()` wrapper.
- Continue testing Git, GitHub CLI, Bun, and tmux with fake executables on
  `PATH` where integration coverage is needed.
- Retain targeted injection already used for interactive confirmation and
  workspace tests.
- Do not inject output or infrastructure into every helper merely for
  architectural uniformity.

This phase does not normalize signal behavior, output handling, or process
errors. Any observable correction belongs to the functional work.

## Canonical test suite

Add one executable runner:

```text
tests/archon-cli/run.sh
```

It must run, in deterministic order:

1. Archon CLI Node tests.
2. Root and domain integration tests.
3. Workspace adapter tests using fake tmux state.
4. Installation-layout tests.
5. Migration tests.
6. Node syntax checks for the executable and all `.mjs` files.
7. Bash syntax checks for relevant scripts.
8. ShellCheck when available.
9. `git diff --check`.

It must use temporary homes and fake external commands. It must not run the
complete setup script, contact real GitHub services or tmux state, or launch
real editors, Codex sessions, or development servers.

Document this runner in the relevant contributor instructions.

## Characterization coverage

Before or alongside the corresponding extraction, cover current behavior for:

- library manifests and package-name validation;
- dependency discovery across supported dependency fields;
- invalid local dependency protocols and paths;
- duplicate package names;
- dependency-first build ordering and cycles;
- missing or invalid build scripts;
- Bun command construction and build failure propagation;
- projects GitHub command construction and response parsing;
- organization and repository blacklist validation;
- libraries GitHub response validation;
- local repository discovery;
- clone destination conflicts and clone command construction;
- current help, output-stream, and exit-status behavior.

Use black-box command coverage where practical. Extracted pure functions may be
tested directly. Do not add a public CLI surface solely for testing.

Existing destructive workflow, synchronization, workspace, installation, and
migration coverage must remain.

## Implementation sequence

Implementation is divided into the tasks in [`tasks.md`](./tasks.md):

1. Establish the canonical verification runner.
2. Strengthen current-behavior characterization coverage.
3. Remove mutable root state.
4. Extract libraries build and dependency logic.
5. Extract projects GitHub inventory logic.
6. Extract libraries GitHub inventory logic.
7. Audit, document, and close the internal proposal.

Each task must leave the CLI working and independently verified. Do not combine
the functional proposal with these tasks.

## Verification

For every task:

- Run `tests/archon-cli/run.sh` once it exists.
- Run `node --check` on changed executable and `.mjs` files.
- Run `bash -n` on changed Bash scripts.
- Run ShellCheck when available.
- Run `git diff --check`.
- Do not execute the complete setup script against the real home directory.

## Acceptance criteria

The internal work is complete when:

- One documented runner executes the complete focused suite safely.
- Characterization coverage protects the extracted domain behavior.
- No invocation-specific root is stored in mutable module state.
- Invocations with different roots do not affect one another.
- Libraries build and dependency logic is a cohesive tested unit.
- Projects and libraries GitHub parsing and validation logic is independently
  testable without real network access.
- Direct filesystem access and the small subprocess boundary remain simple.
- No universal runtime context, service container, or logging abstraction was
  introduced.
- No public behavior, output, side effect, or exit status changed.
- Runtime installation still excludes development instructions, READMEs, and
  tests.
- The Archon CLI migration remains repeat-safe.
- `setup.sh` remains convergent and repeat-safe.
- Node and Bash syntax checks pass.
- ShellCheck passes when available.
- `git diff --check` passes.
