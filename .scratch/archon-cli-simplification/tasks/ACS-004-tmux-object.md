# ACS-004: Introduce a small tmux operations object

Status: pending

Depends on: ACS-003

Source: [Task index](../tasks.md)

## Outcome

Let workspace orchestration depend on named tmux operations so group tests can
use small fake objects instead of interpreting tmux argument arrays.

## Acceptance checklist

- [ ] Add a factory returning plain methods that bind existing run/capture
      dependencies; use no classes or `this` binding.
- [ ] Start with session existence, editor-session creation, and stopping.
      Add listing or other operations only where actual callers benefit.
- [ ] Construct defaults at the workspace boundary and allow callers/tests to
      supply a fake operations object without invoking real commands.
- [ ] Adapt the shared lifecycle and relevant group callers to that object.
- [ ] Simplify group fakes to named operations; preserve assertions about
      definitions, discovery, repeat behavior, and failures.
- [ ] Retain detailed tmux command and rollback verification at the tmux layer,
      and actual CLI wiring/attachment coverage in fake-tmux integration tests.
- [ ] Preserve command arrays, process-result handling, and caller-specific
      treatment of missing servers/sessions; do not normalize behavior as an
      incidental part of this refactor.
- [ ] Remove obsolete wrappers/fake machinery created by this refactor and
      confirm the object reduces total complexity rather than adding a layer.

## Verification

Run workspace tests and fake-tmux adapter checks, including terminal attachment
and rollback failures. Ensure injected fakes cannot fall through to production
tmux execution. Run the checks in the task index.
