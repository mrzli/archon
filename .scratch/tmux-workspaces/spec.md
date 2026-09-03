# Tmux Workspace Restructuring

Status: completed and archived

Completed: 2026-09-03

The implementation and isolated verification are complete. Enduring operational
instructions are documented in the root README; this specification is retained
as the archived design and requirement record.

## Context

The managed `data/home/projects/workspaces/` directory contains tmux launchers
for directory hub sessions, project groups, and aggregate start and stop
operations. The scripts work, but some names do not clearly describe their
responsibilities and separate start and stop files duplicate group ownership
information.

## Problems

- `other-start.sh` and `other-stop.sh` manage a specific collection of
  miscellaneous personal projects, rather than an undefined "other" category.
- `workspaces-start.sh` and `workspaces-stop.sh` manage general directory-root
  sessions named `workspaces`, `projects`, and `libs`. Their names do not make
  their role as persistent shell landing points clear.
- Each logical group has separate start and stop files. In particular, the
  miscellaneous project list is duplicated and can drift.
- Missing project directories are handled inconsistently. The hub
  script skips them, while the flashcards and miscellaneous-project scripts can
  pass nonexistent working directories to tmux.
- The aggregate start script can continue after a partial failure and then
  attach to the `workspaces` session, making that failure easy to overlook.

## Proposed Structure

Keep logical groups separate, but combine each group's start and stop behavior:

```text
data/home/projects/workspaces/
├── all.sh
├── hubs.sh
├── flashcards.sh
├── jslibs.sh
└── misc-projects.sh
```

Each script accepts `start` or `stop` as its first argument:

```bash
./flashcards.sh start
./flashcards.sh stop
./all.sh start
./all.sh stop
```

The groups have these responsibilities:

- `hubs.sh` manages shell-only sessions that act as persistent landing points
  for the workspace scripts, personal projects, and JavaScript libraries
  directories. The group can later include other broad roots, such as a
  learning directory or the top-level projects directory, without changing its
  responsibility.
- `flashcards.sh` manages the frontend and backend sessions, including their
  development commands.
- `jslibs.sh` discovers Git repositories under the JavaScript libraries root
  and manages one session per repository.
- `misc-projects.sh` manages the explicit list currently owned by the `other`
  scripts.
- `all.sh` invokes the other groups and attaches or switches to the primary
  hub session after a successful start.

Keep the implementations within each group for now. A shared shell library
would add indirection and is not justified by the current amount of duplicate
tmux setup code.

## Behavior

- Starting an existing session does nothing.
- Stopping an absent session succeeds.
- Starting a group skips a missing project directory and reports it clearly.
- Repeated starts do not create duplicate sessions or windows.
- Group definitions, including fixed project lists, have one source of truth.
- Aggregate operations report partial failures rather than hiding them.

## Location

Keep the scripts in `data/home/projects/workspaces/` while it remains the
intentional launcher and hub directory. Moving commands to
`data/home/.local/bin/` or configuration to `data/home/.config/tmux/` is a
separate decision and is not required for this restructuring.

## Implementation

1. Combine each start and stop pair into one action-based script.
2. Rename the general root-session group from `workspaces` to `hubs`.
3. Rename the explicit miscellaneous project group from `other` to
   `misc-projects`.
4. Update the aggregate script to call the renamed group scripts and propagate
   failures appropriately.
5. Add consistent missing-directory checks and messages.
6. Remove the replaced start and stop files after their replacements are
   verified.

## Verification

- Run `bash -n` on every changed shell script.
- Run ShellCheck when it is available.
- Verify focused start and stop operations without running the full workstation
  setup script.
- Start each group twice and confirm that no sessions or windows are
  duplicated.
- Stop each group twice and confirm that both runs succeed.
- Test a missing project directory and confirm that it is reported without
  causing unrelated groups to be skipped.
- Run `git diff --check`.
