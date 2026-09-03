# Archon CLI and Managed Tools

Status: proposed

## Context

Archon currently installs three separate collections of workstation scripts in
the directories on which they operate:

- `projects.mjs` is installed in `~/projects/personal`.
- `libs.mjs` is installed in `~/projects/personal/mrzli-jslib`.
- Five Bash launchers are installed in `~/projects/workspaces`.

This couples executable location to managed data location, duplicates tmux
launcher logic, and makes development-only files such as `AGENTS.md` and tool
READMEs part of the home overlay. The tools also lack one consistent command
available through `PATH`.

## Goals

- Provide one `archon` command and the short alias `a` through `~/.local/bin`.
- Move the projects, libraries, and workspace tools into this repository as
  one organized JavaScript codebase.
- Preserve tool-specific instructions with one common `AGENTS.md` and narrower
  `AGENTS.md` overrides for each tool.
- Install only runtime files; do not install development instructions, READMEs,
  tests, or scratch documents.
- Keep source and installed runtime paths sufficiently alike that the same
  executable works directly from the repository and after installation.
- Make installation convergent, repeat-safe, and protective of unrelated files.
- Preserve the current projects and libraries command behavior unless this
  specification explicitly changes it.
- Preserve the current tmux session behavior, except for removing hubs and
  changing the command interface.

## Non-goals

- Creating a general plugin system or configurable command registry.
- Supporting shells or operating systems outside the current Omarchy/Arch
  environment.
- Making the fixed personal project paths user-configurable.
- Installing a Node package or third-party npm dependencies.
- Changing the repository synchronization, deletion, pruning, build, or graph
  semantics of the existing projects and libraries tools.

## Command interface

The public commands are:

```text
archon projects <command> [options]
archon libs <command> [options]
archon workspaces <start|stop>
archon workspaces <group> <start|stop>
```

`a` is an exact alias for `archon`:

```text
a projects status
a libs build
a workspaces start
```

The root command prints help and exits successfully for `archon help`, `-h`,
or `--help`. A missing or unknown tool prints concise usage to standard error
and exits with status 2.

### Projects

`archon projects` retains the current commands and behavior:

```text
delete
prune
remote
status
sync
help
```

It operates on the fixed root `~/projects/personal`.

### Libraries

`archon libs` retains the current commands and behavior:

```text
build
delete
graph
prune
remote
status
sync
help
```

It operates on the fixed root `~/projects/personal/mrzli-jslib`.

### Workspaces

The workspace groups are:

```text
flashcards
jslibs
misc-projects
```

When no group is supplied, the action applies to every group:

```text
archon workspaces start
archon workspaces stop
```

A named group limits the action to that group:

```text
archon workspaces flashcards start
archon workspaces jslibs stop
archon workspaces misc-projects start
```

The action remains required. Bare `archon workspaces` displays workspace help;
it does not mutate tmux state.

Aggregate start uses the group order shown above. Aggregate stop uses reverse
order. Every group is attempted after a group failure, and the aggregate exits
nonzero if any group fails. Aggregate start no longer attaches to or switches
to a `workspaces` tmux session.

The existing `hubs` group and its `workspaces`, `projects`, and `libs` tmux
sessions are removed. Commands are available through `PATH`, so hub sessions
are no longer needed for locating or invoking scripts.

Workspace behavior otherwise remains unchanged:

- Starting an existing session does nothing.
- Stopping an absent session succeeds.
- Missing configured directories are reported and skipped.
- Repeated starts do not duplicate sessions or windows.
- Actual tmux command failures produce a nonzero result.
- Existing session names, window names, commands, and layouts are preserved.

## Runtime choice

All tool behavior is implemented in dependency-free Node.js using ECMAScript
modules. The `archon` executable is also JavaScript:

```javascript
#!/usr/bin/env node
```

Using Node for the entry point is simpler than a Bash wrapper: argument
dispatch, error handling, and module loading stay in one runtime. The filename
has no extension because it is a command; internal modules use `.mjs`.

Subprocesses are invoked with argument arrays and without a shell unless a tmux
window intentionally needs to receive a command string.

## Repository layout

`tools/` is shaped like an installation prefix:

```text
tools/
├── AGENTS.md
├── README.md
├── bin/
│   └── archon
└── lib/
    └── archon/
        ├── cli.mjs
        ├── shared/
        │   └── ...
        ├── projects/
        │   ├── AGENTS.md
        │   ├── README.md
        │   ├── src/
        │   │   └── ...
        │   └── tests/
        │       └── ...
        ├── libs/
        │   ├── AGENTS.md
        │   ├── README.md
        │   ├── src/
        │   │   └── ...
        │   └── tests/
        │       └── ...
        └── workspaces/
            ├── AGENTS.md
            ├── README.md
            ├── src/
            │   └── ...
            └── tests/
                └── ...
```

`tools/AGENTS.md` defines conventions shared by the complete CLI. Each tool's
`AGENTS.md` contains only its narrower domain rules and overrides. Existing
useful projects and libraries instructions are migrated rather than discarded.

The entry point imports `../lib/archon/cli.mjs`. That relative path resolves in
both environments:

```text
tools/bin/archon                    -> tools/lib/archon/cli.mjs
~/.local/bin/archon                -> ~/.local/lib/archon/cli.mjs
```

The repository command can therefore be exercised without installation:

```bash
./tools/bin/archon --help
./tools/bin/archon projects status
./tools/bin/archon workspaces start
```

Tests must use temporary roots and controlled subprocesses where a command
could otherwise mutate real projects or tmux state.

## Installation

Tool installation is separate from the `data/home/` overlay.

`setup.sh` installs:

```text
tools/bin/archon       -> ~/.local/bin/archon
tools/lib/archon/...   -> ~/.local/lib/archon/...
~/.local/bin/a         -> archon
```

Only the executable and runtime module directories are installed. The install
operation uses an explicit runtime allowlist; it does not copy `AGENTS.md`,
READMEs, or tests.

No general home-overlay ignore file is introduced. `data/home/` remains a
literal managed overlay, while `tools/` has separate installation semantics.
An ignore file would make all home copying depend on negative exclusions and
would make accidental installation easier when new development files are
added. An explicit runtime allowlist makes the deployment boundary visible.

`~/.local/lib/archon` is an explicitly managed replacement directory. Setup
may replace that exact directory to remove obsolete runtime modules, but must
not remove or alter sibling directories under `~/.local/lib`.

The `~/.local/bin/archon` executable is installed with executable permissions.
Before replacing it, setup must accept only an absent path or the expected
Archon-managed file. It must refuse to overwrite an unrelated file or symlink.

The alias is a relative symlink:

```text
~/.local/bin/a -> archon
```

Setup leaves the correct symlink unchanged, creates it when absent, and refuses
to overwrite any unexpected file or symlink at that path.

Omarchy already includes `~/.local/bin` in `PATH`; Archon does not add a second
PATH modification.

## Fixed roots and safety

Moving the tools means their target roots can no longer be inferred from the
entry-point location. Runtime context defines the fixed roots from the user's
home directory:

```text
projects:   ~/projects/personal
libs:       ~/projects/personal/mrzli-jslib
workspaces: existing fixed project directories beneath ~/projects
```

Internal functions receive the home/root context explicitly so tests can use
temporary directories. Production defaults to the real user home.

The current destructive-command protections remain in place. Checks that now
require a script to reside in a specially named directory are replaced with
checks that the resolved operation root exactly matches the expected fixed
root. Dry-run, inventory validation, Git cleanliness checks, confirmations,
and inventory revalidation are preserved.

## Migration

After the new CLI passes focused tests, remove the source versions of:

```text
data/home/projects/personal/projects.mjs
data/home/projects/personal/mrzli-jslib/libs.mjs
data/home/projects/workspaces/all.sh
data/home/projects/workspaces/flashcards.sh
data/home/projects/workspaces/hubs.sh
data/home/projects/workspaces/jslibs.sh
data/home/projects/workspaces/misc-projects.sh
```

Setup must remove only the corresponding legacy files previously managed by
Archon. It must not delete project directories or unrelated contents. Any
legacy README or `AGENTS.md` cleanup must be enumerated separately after
confirming that the destination file exists solely for the old installed tool;
it must not remove documentation belonging to an independent repository.

Remove `projects/workspaces` from `data/home-replace-directories.txt` if Archon
no longer manages any content in that directory. Do not delete the destination
directory merely because its launcher files moved.

Update the root README with the installed CLI interface and remove the obsolete
five-launcher documentation. Archive the completed tmux-workspaces scratch
specification as historical context; do not rewrite it as if the earlier work
had never existed.

## Implementation plan and verification

1. Establish `tools/` instructions and the Node entry point.
   Verify root help, alias-independent invocation, exit statuses, and
   `node --check` for every module.
2. Move the projects implementation behind `archon projects` without changing
   its command behavior.
   Run focused help/status tests and deletion/prune dry-runs against controlled
   fixtures.
3. Move the libraries implementation behind `archon libs` without changing its
   command behavior.
   Run focused help/status/graph tests and deletion/prune dry-runs against
   controlled fixtures.
4. Reimplement workspace management in JavaScript, omitting hubs and aggregate
   attach/switch behavior.
   Port the fake-tmux harness and verify each group, aggregate ordering,
   idempotency, missing directories, and injected failures.
5. Add explicit repeat-safe tool installation and guarded `a` symlink creation
   to `setup.sh`.
   Test installation twice into a temporary home and compare the resulting
   runtime tree and links.
6. Remove the exact legacy managed launchers and script files after their new
   commands pass.
   Verify that unrelated home/project fixtures remain untouched.
7. Update durable documentation and close or archive this proposal.

For the final change set:

- Run `node --check` on every executable and `.mjs` module.
- Run the complete focused CLI test suite with temporary filesystem roots and
  fake external commands.
- Run `bash -n setup.sh`.
- Run `shellcheck setup.sh` when ShellCheck is available.
- Run `git diff --check`.
- Do not execute the complete setup script against the real home directory as
  a test.
