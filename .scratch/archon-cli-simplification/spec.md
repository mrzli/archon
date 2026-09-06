# Archon CLI simplification

Status: partially implemented; ACS-001 through ACS-003 and command layout complete, remaining scope provisional

Created: 2026-09-06

Implementation tasks: [Tasks, ordered from simplest](./tasks.md)

## Purpose

Simplify Archon CLI by removing duplicated workflows and introducing small
plain objects only where they make dependencies and tests easier to understand.
Avoid classes. ACS-001 was implemented and committed as `91be803`. The command
layout follow-up was committed as `f68d886`; ACS-002 is also committed.
ACS-003 is implemented but uncommitted. The remaining recommendations are
provisional, not current behavior.

## Implementation progress

ACS-001 extracted identical argument helpers into `shared/arguments.mjs` for
projects, libraries, sync, and destructive workflows. See its task record for
verification results. ACS-002 now shares status orchestration through
`shared/status-workflow.mjs`, preserving domain discovery, inspection, help,
and empty-result messages. Its task record contains verification results.
ACS-003 shares configured editor-session management and startup error reporting
in `commands/workspaces/src/editor-sessions.mjs`. Jslibs retains its distinct
discovery and stopping logic; low-level tmux behavior is unchanged. See the
task record for verification. ACS-004 and ACS-005 remain pending.

### Command layout follow-up (2026-09-06)

At the user's request, moved `libs/`, `projects/`, and `workspaces/` under
`lib/archon/commands/`. Each command's `src/index.mjs` exports only its entry
function, defined directly as `runLibraries`, `runProjects`, or `runWorkspaces`.
`commands/index.mjs` and `shared/index.mjs` use `export *` to re-export their
modules. Same-directory imports remain direct; command internals are still
available to focused tests via direct module imports.

Updated runtime/test imports, documentation, installation-layout assertions,
and migration prerequisite paths. No migration deletion target or provisioning
operation changed. Durable layout/import conventions are in the component
AGENTS.md. READMEs are usage-only; contributor and test implementation guidance
belongs in the relevant AGENTS.md files.

The complete verification runner passed: 126 Node tests, five workspace adapter
cases, one installation-layout case, two migration cases, and Node/Bash syntax
and whitespace checks. ShellCheck was unavailable. Checks also confirmed that
relative runtime imports resolve, no module imports its same-directory barrel,
the commands barrel exposes exactly three entry functions, and the shared
barrel preserves all existing exports without collisions. Moved module bodies
are unchanged apart from entry-function names and imports.

## Current findings

These findings record the review before implementation began.

- `workspaces/src/flashcards.mjs` and `workspaces/src/misc-projects.mjs`
  duplicate directory checks, existing-session checks, editor-session creation,
  rollback error reporting, stopping, and failure accumulation.
- `workspaces/src/jslibs.mjs` repeats editor-session startup behavior but has
  distinct repository discovery and prefix-based session stopping.
- Workspace tests already inject functions through context objects. Group
  fakes interpret low-level tmux argument arrays to simulate session behavior.
- Shared sync and destructive workflows already accept replacement operations.
  CLI integration tests use fake executables, and repository inspection tests
  use temporary real Git repositories. A mocking framework is unnecessary.
- Projects and libraries have nearly identical status handlers and status
  argument parsers. Small argument helpers are also repeated.
- `visit()` inside `orderPackagesForBuild()` captures traversal state naturally.
  Its nesting is useful and does not itself justify extraction.
- `libs/src/build.mjs` reads manifests and resolves filesystem paths, despite
  the earlier internal proposal describing pure domain modules.

Paths above are relative to `components/archon-cli/lib/archon/`.

## Recommended first pass

### 1. Share workspace lifecycle orchestration

Extract a small `manageEditorSessions(action, definitions, dependencies)`
helper for the lifecycle repeated by flashcards and miscellaneous projects.
Group modules should primarily construct their session definitions.

Reuse editor-start behavior for JavaScript libraries where practical, while
keeping its repository discovery and prefix-based stopping distinct. Do not
force the general shell session through an editor-session abstraction.

Preserve missing-directory messages, session definitions, repeat-safe behavior,
rollback, and continued processing after individual failures.

### 2. Introduce a small tmux operations object

Use a factory to bind process dependencies to the existing tmux operations.
An illustrative shape is:

```javascript
function createTmux({ run, capture }) {
  return {
    hasSession: (name) => hasSession(run, name),
    createEditorSession: (definition) =>
      createEditorSession(run, definition),
    stopSession: (name) => stopSession(run, name),
    // Session listing can move behind this boundary too.
  };
}
```

The exact API is provisional. Include only operations required by actual
callers; use closures without classes or `this` binding.

Group tests can supply a plain object with fake methods instead of interpreting
tmux command arrays. Keep detailed command construction and rollback coverage
in tmux tests and preserve integration coverage for actual CLI wiring.

### 3. Share the projects/libraries status workflow

Follow the existing shared sync/destructive workflow pattern. Supply the
domain-specific repository discovery, inspection, help, and empty message.
Share status argument parsing, status output orchestration, and exit-status
calculation where behavior is identical.

Keep repository layouts, repository naming, and GitHub inventory policies in
their respective domains.

## Secondary candidates

- Consolidate repeated `isHelpRequest` and `acceptsNoArguments` helpers if this
  reduces duplication without creating a general argument-parsing framework.
- Consider shared remote-output formatting only if its boundary remains small.
  Projects use visibility values while libraries use `isPrivate`; preserve
  those distinctions and their existing empty-output behavior.
- Consider separating manifest loading/path resolution from dependency-graph
  calculation if it materially simplifies focused tests. This is lower
  priority than workspace and status duplication. Preserve filesystem identity
  and symlink resolution semantics.

## Keep as-is unless a concrete need emerges

- Keep the nested graph traversal `visit()` function. Moving it outside would
  require passing several pieces of traversal state or adding an object.
- Keep simple binding callbacks such as
  `() => findLocalRepositories(rootDir)` where they clarify invocation scope.
- Keep existing sync/destructive options objects rather than adding another
  container layer around them.
- Keep direct filesystem APIs with temporary-directory tests and retain real
  local Git tests where they protect Git behavior.

## Constraints

- Preserve commands, help, output streams and text, exit statuses, session
  layouts, repository policies, and installation behavior.
- Preserve deletion confirmations, cleanliness checks, operation-root checks,
  and remote-inventory revalidation.
- Do not add classes, a universal service container, a dependency-injection
  framework, a filesystem or logging abstraction, runtime dependencies, or a
  general plugin/command registry.
- Do not create an object for every external tool merely for consistency.
- Keep changes focused; adapt existing tests without duplicating behavioral
  coverage or rebuilding the recently pruned test infrastructure.

The earlier internal architecture and test-pruning specs are completed records.
This proposal does not rewrite their historical scope or constraints.

## Proposed implementation and verification sequence

1. Consolidate identical argument helpers; verify help, invalid arguments,
   output streams, and exit statuses remain unchanged.
2. Extract shared status orchestration; verify both domains retain argument,
   missing-root, output, and exit-status behavior.
3. Extract shared workspace lifecycle behavior; verify existing group behavior,
   repeat-safe starts/stops, missing directories, rollback, and failure handling.
4. Introduce the tmux object and simplify group fakes; verify tmux command tests
   and fake-tmux CLI integration still protect the lower-level boundary.
5. Audit the final simplification, run complete verification, and document the
   implemented boundaries.

The task index defines execution order; the earlier design sections group the
recommendations by topic. Remote formatting and build loading remain deferred
candidates rather than required implementation tasks.

For implementation, follow the component instructions and run:

```bash
components/archon-cli/test.sh
bash tests/archon-cli/run.sh
bash tests/archon-cli/run.sh < /dev/null
git diff --check
```

Run `node --check` on changed executable and `.mjs` files. Use temporary homes,
local Git fixtures, and fake external commands; never run complete workstation
setup, operate on user repositories, or use the real tmux server as a test.

Success means less duplicated orchestration and simpler group fakes, with no
observable behavior changes. Review the resulting code for net simplification;
do not retain an abstraction merely because this proposal suggested it.

When implementation is complete, update relevant durable documentation with
the final boundaries and mark this proposal completed or archive it.
