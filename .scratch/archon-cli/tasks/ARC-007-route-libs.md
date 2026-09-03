# ARC-007: Route libraries through a relocated copy

Status: completed

Area: Libraries

Depends on: ARC-005

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Provide `archon libs` using a minimally changed relocated implementation while
preserving the legacy command.

## Acceptance checklist

- [x] The libraries implementation is copied into its tool source directory.
- [x] `archon libs` invokes it as a child Node process.
- [x] Arguments, standard streams, signals where practical, and exit status propagate.
- [x] No modularization or shared-code extraction is included.
- [x] The legacy `libs.mjs` remains functional.

## Verification

- Compare old and new help, status, graph, invalid calls, and controlled dry-runs.
- Run Node syntax checks and `git diff --check`.

## Verification evidence

Copied the libraries implementation unchanged to
`data/home/.local/lib/archon/libs/src/libs.mjs`. The root CLI routes `libs`
through the child-process adapter already introduced for projects. The legacy
script remains in place and its README notes the additional `archon libs`
route.

Six root-command tests passed, including libraries wrapper help, graph failure,
invalid-command, delete dry-run, and prune dry-run behavior. The four-test
baseline suite passed once against the legacy libraries source and once against
the relocated source. Both installation-layout tests and all seven existing
tmux-workspace tests passed. All relevant Node and Bash syntax checks and
`git diff --check` passed; ShellCheck was unavailable.
