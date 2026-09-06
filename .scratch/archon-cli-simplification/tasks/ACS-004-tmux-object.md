# ACS-004: Introduce a small tmux operations object

Status: completed

Completed: 2026-09-06

Depends on: ACS-003

Source: [Task index](../tasks.md)

## Outcome

Let workspace orchestration depend on named tmux operations so group tests can
use small fake objects instead of interpreting tmux argument arrays.

## Acceptance checklist

- [x] Add a factory returning plain methods that bind existing run/capture
      dependencies; use no classes or `this` binding.
- [x] Start with session existence, editor-session creation, and stopping.
      Add listing or other operations only where actual callers benefit.
- [x] Construct defaults at the workspace boundary and allow callers/tests to
      supply a fake operations object without invoking real commands.
- [x] Adapt the shared lifecycle and relevant group callers to that object.
- [x] Simplify group fakes to named operations; preserve assertions about
      definitions, discovery, repeat behavior, and failures.
- [x] Retain detailed tmux command and rollback verification at the tmux layer,
      and actual CLI wiring/attachment coverage in fake-tmux integration tests.
- [x] Preserve command arrays, process-result handling, and caller-specific
      treatment of missing servers/sessions; do not normalize behavior as an
      incidental part of this refactor.
- [x] Remove obsolete wrappers/fake machinery created by this refactor and
      confirm the object reduces total complexity rather than adding a layer.

## Verification

Run workspace tests and fake-tmux adapter checks, including terminal attachment
and rollback failures. Ensure injected fakes cannot fall through to production
tmux execution. Run the checks in the task index.

## Completion record

Added `createTmux({ run, capture })`, returning named operations for existence,
editor/shell creation, repeat-safe stopping, direct killing, listing, and exact
attachment. `runWorkspaces` constructs the default object once or uses the
supplied `context.tmux` unchanged. Group/lifecycle functions use the object;
process execution defaults remain at the workspace boundary. Caller-specific
list-error handling and the existing low-level rollback logic are preserved.

Group fakes now use named methods and session definitions. Detailed rollback
checks exercise the real factory; shell/list/attachment command contracts were
moved to tmux-layer checks. An additional wiring case proves a supplied object
reaches real group and attachment behavior without using process functions.
No classes, mocking framework, or generic fixture abstraction were added.

The full `bash tests/archon-cli/run.sh` suite passed: 129 Node tests, five
workspace adapter cases, one installation-layout case, two migration cases,
and Node/Bash syntax and whitespace checks. ShellCheck was unavailable. The
complete runner used isolated fixtures outside the sandbox. Contributor
instructions were updated in AGENTS.md files; READMEs remain usage-only.
ACS-004 was subsequently committed as `df2f017`; ACS-003 was committed as
`d91f2b6` before this work.
