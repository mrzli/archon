# ARC-006: Route projects through a relocated copy

Status: completed

Area: Projects

Depends on: ARC-005

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Provide `archon projects` using a minimally changed relocated implementation
while preserving the legacy command.

## Acceptance checklist

- [x] The projects implementation is copied into its tool source directory.
- [x] `archon projects` invokes it as a child Node process.
- [x] Arguments, standard streams, signals where practical, and exit status propagate.
- [x] No modularization or shared-code extraction is included.
- [x] The legacy `projects.mjs` remains functional.

## Verification

- Compare old and new help, status, invalid calls, and controlled dry-runs.
- Run Node syntax checks and `git diff --check`.

## Verification evidence

Copied the projects implementation unchanged to
`data/home/.local/lib/archon/projects/src/projects.mjs`. The root CLI invokes it
with the current Node executable, inherited standard streams, forwarded
arguments, child exit status, and child termination signal. The legacy script
remains in place and its README notes the additional `archon projects` route.

Five root-command tests passed, including wrapper help, invalid-command, delete
dry-run, and prune dry-run behavior. The four-test baseline suite passed once
against the legacy projects source and once against the relocated source. Both
installation-layout tests and all seven existing tmux-workspace tests passed.
All relevant Node and Bash syntax checks and `git diff --check` passed;
ShellCheck was unavailable.
