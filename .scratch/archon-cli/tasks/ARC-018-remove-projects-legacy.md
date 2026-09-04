# ARC-018: Remove the legacy projects entry point

Status: completed

Area: Migration cleanup

Depends on: ARC-013, ARC-017

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Retire the old projects script only after `archon projects` is complete, and
establish the separate migration used for every legacy runtime file retired by
this specification.

## Acceptance checklist

- [x] `projects.mjs` is removed from the home overlay.
- [x] The dedicated CLI migration removes only the exact previously managed destination script.
- [x] The migration enumerates all legacy projects, libraries, and workspace runtime files from this specification.
- [x] Setup contains no legacy-file cleanup.
- [x] The migration verifies all replacements before removing anything and is repeat-safe.
- [x] Enduring usage documentation moves to the Archon projects README.
- [x] Destination README or agent files are preserved unless separately proven obsolete and managed.
- [x] Personal project directories and unrelated files are untouched.

## Verification

- Test the dedicated migration in a temporary home with unrelated neighboring files.
- Run the full projects suite through `archon`.
- Run setup syntax checks and `git diff --check`.

Verified with the repeat-safe temporary-home migration test, the complete
Archon CLI test suite, `bash -n`, the projects module syntax check, and
`git diff --check`. ShellCheck was unavailable.
