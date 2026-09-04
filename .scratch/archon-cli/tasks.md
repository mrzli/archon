# Archon CLI implementation tasks

Status: proposed

Source: [Archon CLI and Managed Tools](./spec.md)

These tasks intentionally separate relocation, routing, behavior changes,
deduplication, installation filtering, and cleanup. Each completed task should
leave the old or new interface functional and independently verifiable.

## Phase 1: Freeze current behavior

### [ARC-001: Establish baseline contract coverage](./tasks/ARC-001-baseline-contracts.md)

- Record the current projects and libraries help, command dispatch, and exit
  status contracts.
- Retain safe dry-run coverage for destructive commands.
- Run the existing isolated workspace launcher suite unchanged.
- Add only the minimum harness needed to compare old and new entry points.

Verify: all current entry points pass before relocation begins.

### [ARC-002: Decouple projects target from script location](./tasks/ARC-002-projects-fixed-root.md)

- Change the existing `projects.mjs` to resolve its fixed target as
  `~/projects/personal`, rather than treating its own directory as the target.
- Replace the directory-name deletion guard with an exact resolved-root guard.
- Preserve the current direct command and every other behavior.

Verify: baseline projects checks and controlled `delete --dry-run` and
`prune --dry-run` checks pass through the existing entry point.

### [ARC-003: Decouple libraries target from script location](./tasks/ARC-003-libs-fixed-root.md)

- Change the existing `libs.mjs` to resolve its fixed target as
  `~/projects/personal/mrzli-jslib`.
- Replace the directory-name deletion guard with an exact resolved-root guard.
- Preserve the current direct command and every other behavior.

Verify: baseline libraries checks and controlled destructive dry-runs pass
through the existing entry point.

## Phase 2: Introduce the new command without removing old commands

### [ARC-004: Add the tool source skeleton](./tasks/ARC-004-tool-skeleton.md)

- Add the prefix-shaped `data/home/.local/bin` and
  `data/home/.local/lib/archon` layout.
- Add the common and tool-specific `AGENTS.md` files.
- Add the JavaScript `data/home/.local/bin/archon` entry point and root help/dispatch
  validation, without routing projects, libraries, or workspaces yet.

Verify: `./data/home/.local/bin/archon --help`, missing-command behavior, unknown-command
behavior, and `node --check` pass. Existing commands remain untouched.

### [ARC-005: Install the initial `archon` and `a` commands](./tasks/ARC-005-initial-install.md)

- Add `archon` and the relative `a -> archon` symlink to `data/home/.local/bin`.
- Add `.local/lib/archon` to `data/home-replace-directories.txt`.
- Use the existing home-overlay copy operation unchanged.
- At this transitional stage, development metadata inside the tool tree is
  copied too; do not introduce filtering yet.

Verify: copy the overlay twice into a temporary home, invoke both names, and
verify the existing replacement-directory flag replaces only
`.local/lib/archon`. Existing direct commands remain installed.

### [ARC-006: Route projects through a relocated copy](./tasks/ARC-006-route-projects.md)

- Copy the current projects implementation into its new tool source directory.
- Make `archon projects` invoke that relocated implementation as a child Node
  process, forwarding arguments, standard streams, and exit status.
- Do not modularize or deduplicate the implementation in this task.
- Keep the legacy `projects.mjs` in place.

Verify: compare legacy and new help, safe status behavior, error statuses, and
controlled destructive dry-runs.

### [ARC-007: Route libraries through a relocated copy](./tasks/ARC-007-route-libs.md)

- Copy the current libraries implementation into its new tool source directory.
- Make `archon libs` invoke that relocated implementation as a child Node
  process, forwarding arguments, standard streams, and exit status.
- Do not modularize or deduplicate the implementation in this task.
- Keep the legacy `libs.mjs` in place.

Verify: compare legacy and new help, status and graph behavior, error statuses,
and controlled destructive dry-runs.

## Phase 3: Replace workspace Bash incrementally

### [ARC-008: Add a JavaScript workspace orchestrator over legacy launchers](./tasks/ARC-008-workspaces-adapter.md)

- Add `archon workspaces` command parsing and aggregate orchestration in Node.
- Initially delegate every group operation to the existing Bash launchers.
- Preserve hubs and aggregate attach/switch behavior temporarily.
- Make aggregate execution capable of routing each group independently so a
  later task can replace one group without changing the others.

Verify: the new command matches current group order, partial-failure behavior,
attach/switch behavior, and group results using the fake tmux harness. Old
launcher commands remain functional.

### [ARC-009: Convert the flashcards workspace group](./tasks/ARC-009-workspaces-flashcards.md)

- Implement only the flashcards group in JavaScript.
- Route both named and aggregate operations to it.
- Continue delegating every other group to Bash.

Verify: missing directories, start twice, stop twice, window commands and
layout, and injected failures match the legacy launcher.

### [ARC-010: Convert the jslibs workspace group](./tasks/ARC-010-workspaces-jslibs.md)

- Implement only dynamic JavaScript-library session discovery and management
  in JavaScript.
- Reuse the shared workspace operations established by ARC-009.
- Continue delegating the remaining groups to Bash.

Verify: discovery, session naming, start/stop idempotency, missing root, and
tmux list failure behavior match the legacy launcher.

### [ARC-011: Convert the miscellaneous-projects workspace group](./tasks/ARC-011-workspaces-misc.md)

- Implement only the configured miscellaneous project sessions in JavaScript.
- Route all retained workspace groups to JavaScript; leave hubs delegated to
  Bash until the next task.

Verify: project mapping, missing directories, window commands and layout,
idempotency, and injected failures match the legacy launcher.

### [ARC-012: Remove hubs and aggregate attachment behavior](./tasks/ARC-012-remove-hubs-behavior.md)

- Remove hubs from the new workspace aggregate.
- Remove automatic attach/switch behavior from the new workspace aggregate.
- Accept only `flashcards`, `jslibs`, and `misc-projects` through `--group`/`-g`.
- Keep legacy shell entry points temporarily, including `hubs.sh`, so rollback
  remains possible until cleanup.

Verify: final workspace command grammar, forward/reverse aggregate order,
partial failures, and absence of attach/switch attempts.

## Phase 4: Stabilize installation and shared code

### [ARC-013: Add home-overlay ignores](./tasks/ARC-013-runtime-only-install.md)

- Add one global home-copy ignore list using paths relative to `data/home`.
- Update the overlay copy operation to honor that list.
- Ignore only narrowly scoped Archon tool `AGENTS.md`, READMEs, and tests.
- Do not retain one-time cleanup for files absent from the target installation.

Verify: copy twice into a temporary home; runtime files exist, development
files do not, previously copied development files disappear, and unrelated
managed home files remain untouched.

### [ARC-014: Extract shared low-level JavaScript utilities](./tasks/ARC-014-shared-low-level.md)

- Convert the relocated projects and libraries implementations from child
  scripts into importable modules with explicit `main(arguments, context)`
  boundaries.
- Extract only common process, Git invocation, path, and error-normalization
  utilities.
- Keep domain commands and output unchanged.

Verify: all projects and libraries parity checks continue to pass through both
the direct module harness and `archon`.

### [ARC-015: Extract shared repository inspection behavior](./tasks/ARC-015-shared-inspection.md)

- Share local Git discovery and status inspection used by projects and
  libraries.
- Keep their different root layouts, blacklists, and package behavior in their
  respective modules.

Verify: fixture inventories and formatted status output remain unchanged for
both tools.

### [ARC-016: Extract shared destructive workflows](./tasks/ARC-016-shared-destructive.md)

- Share the common delete/prune argument parsing, cleanliness checks,
  confirmations, and removal orchestration.
- Keep remote-inventory acquisition and tool-specific policy separate.

Verify: all refusal cases, clean and unclean confirmations, dry-runs, inventory
revalidation, and exit statuses remain unchanged.

### [ARC-017: Extract shared synchronization behavior](./tasks/ARC-017-shared-sync.md)

- Share common repository clone/update orchestration only where projects and
  libraries currently have equivalent behavior.
- Do not force unlike GitHub inventory or library-build behavior into a common
  abstraction.

Verify: controlled sync plans, failures, and output remain unchanged for both
tools.

## Phase 5: Remove compatibility files one collection at a time

### [ARC-018: Remove the legacy projects entry point](./tasks/ARC-018-remove-projects-legacy.md)

- Stop copying the old `projects.mjs` from `data/home`.
- Establish a dedicated, explicitly invoked, repeat-safe CLI migration for all
  legacy runtime files retired by this specification; setup performs no
  one-time cleanup.
- Remove only the previously managed projects script after all replacement
  commands are installed.
- Migrate enduring usage documentation to the Archon projects README.
- Do not delete a destination README or `AGENTS.md` without separately proving
  it belongs only to the retired installed tool.

Verify: `archon projects` passes after legacy cleanup and unrelated personal
project fixtures remain unchanged.

### [ARC-019: Remove the legacy libraries entry point](./tasks/ARC-019-remove-libs-legacy.md)

- Stop copying the old `libs.mjs` from `data/home`.
- Retain the exact previously managed libraries script in the dedicated CLI
  migration after removing it from the overlay.
- Preserve files belonging to the independent `mrzli-jslib` repository.

Verify: `archon libs` passes after legacy cleanup and unrelated library
repository files remain unchanged.

### [ARC-020: Remove the legacy workspace launchers](./tasks/ARC-020-remove-workspaces-legacy.md)

- Stop copying the five shell launchers from `data/home`.
- Retain only those exact previously managed destination files in the dedicated
  CLI migration after removing them from the overlay.
- Remove `projects/workspaces` from the replacement-directory list if it no
  longer contains managed files; do not delete the destination directory.
- Retire or adapt the legacy Bash-only test harness after equivalent Node
  coverage is established.

Verify: all new workspace tests pass after legacy cleanup and unrelated files
under `~/projects/workspaces` remain unchanged.

### [ARC-021: Complete documentation and archive the proposal](./tasks/ARC-021-document-and-close.md)

- Document the final CLI, fixed roots, installation paths, alias, and workspace
  groups in Archon's tool-local READMEs; keep the root README setup-focused.
- Confirm installed help and tool-local documentation agree.
- Mark this specification and task index completed and archive them in place.

Verify: full focused test suite, all Node syntax checks, `bash -n setup.sh`,
ShellCheck when available, and `git diff --check` pass.
