# ARC-018: Remove the legacy projects entry point

Status: proposed

Area: Migration cleanup

Depends on: ARC-013, ARC-017

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Retire the old projects script only after `archon projects` is complete.

## Acceptance checklist

- [ ] `projects.mjs` is removed from the home overlay.
- [ ] Setup removes only the exact previously managed destination script.
- [ ] Enduring usage documentation moves to the root README.
- [ ] Destination README or agent files are preserved unless separately proven obsolete and managed.
- [ ] Personal project directories and unrelated files are untouched.

## Verification

- Test migration in a temporary home with unrelated neighboring files.
- Run the full projects suite through `archon`.
- Run setup syntax checks and `git diff --check`.
