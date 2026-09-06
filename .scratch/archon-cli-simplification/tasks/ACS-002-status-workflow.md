# ACS-002: Share projects and libraries status orchestration

Status: completed

Completed: 2026-09-06 (uncommitted)

Depends on: ACS-001

Source: [Task index](../tasks.md)

## Outcome

Replace the duplicated status flow with one small shared workflow, following
the existing sync/destructive options-object pattern.

## Acceptance checklist

- [x] Share status argument parsing, inspection/output orchestration, and
      warning/error exit-status calculation.
- [x] Supply domain-specific discovery, inspection, help, and empty messages
      through narrowly scoped options.
- [x] Preserve no-fetch defaults and the existing `--fetch` behavior.
- [x] Preserve each domain's missing-root and empty-result output.
- [x] Keep repository layouts, names, and discovery policy in their domains.
- [x] Reuse existing repository inspection and status formatting functions.
- [x] Avoid adding another container layer or changing Git execution.

## Verification

Run existing projects/libs CLI, missing-root, exit-status, and repository-status
tests. Check both empty and nonempty paths, help/invalid arguments, and
inspection warnings/failures. Run the checks in the task index.

## Completion record

Added `shared/status-workflow.mjs` with `runStatusWorkflow`. Both domains now
supply discovery, inspection, help, and their unchanged empty-result messages.
Shared modules use direct sibling imports; domains import through the shared
barrel. Existing inspection, Git execution, and tests remain unchanged. The
component AGENTS.md documents the new ownership boundary.

`bash tests/archon-cli/run.sh` passed: 126 Node tests, five workspace adapter
cases, one installation-layout case, two migration cases, and Node/Bash syntax
and whitespace checks. ShellCheck was unavailable. The sandboxed test run hit
the existing subprocess restriction; the full isolated suite passed outside
the sandbox. No workstation setup was executed and no commit was made.
