# ACS-001: Share identical argument helpers

Status: completed

Completed: 2026-09-06

Depends on: none

Source: [Task index](../tasks.md)

## Outcome

Remove the smallest exact duplication before changing workflow boundaries.

## Acceptance checklist

- [x] Move identical `isHelpRequest` and `acceptsNoArguments` behavior from
      projects and libraries into a small shared module.
- [x] Reuse the help predicate in shared sync/destructive workflows where its
      existing semantics match exactly.
- [x] Preserve the exact-one-argument requirement and existing `-h`/`--help`
      handling; leave distinct root/workspace parsing alone.
- [x] Preserve error wording, help destinations, and return/exit statuses.
- [x] Remove only helper definitions and imports made redundant by this change.
- [x] Do not add a general parser, command registry, or configurable framework.

## Verification

Use existing CLI and exit-status tests for help and invalid arguments, plus
shared sync/destructive tests for their argument paths. Run the checks in the
task index. No new helper-only tests are required.

## Completion record

Extracted the unchanged helper bodies into `shared/arguments.mjs`. Projects
and libraries import both helpers; sync and destructive workflows import the
help predicate. Root/workspace parsing and existing tests remain unchanged.

`bash tests/archon-cli/run.sh` passed, including the component suite (126 Node
tests), five workspace adapter cases, one installation-layout case, and two
migration cases. Node syntax checks include the new module; Bash syntax and
`git diff --check` passed. ShellCheck was unavailable.

The initial sandboxed run failed because temporary Git subprocesses returned
`spawnSync git EPERM`; the complete suite passed outside the sandbox using its
isolated fixtures. No workstation setup was executed and no commit was made.
