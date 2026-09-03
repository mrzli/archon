# ARC-013: Add home-overlay ignores

Status: completed

Area: Installation

Depends on: ARC-006, ARC-007, ARC-012

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Teach the shared home-overlay copy operation to exclude development-only files.

## Acceptance checklist

- [x] One repository-wide ignore list contains paths relative to `data/home`.
- [x] Setup changes from plain `cp -a` only in this task and honors the list.
- [x] Rules target Archon tool `AGENTS.md`, READMEs, and tests specifically.
- [x] Setup contains no one-time cleanup for excluded development files.
- [x] Runtime files and unrelated home-overlay files continue to copy normally.
- [x] The operation remains repeat-safe and preserves unrelated destination files.

## Verification

- Copy twice into a temporary home containing unrelated files; compare the
  resulting tree.
- Run `bash -n setup.sh`, ShellCheck when available, and `git diff --check`.

Completed with repeat-copy and managed-replacement tests against a temporary
home, full focused CLI regressions, `bash -n`, and `git diff --check`. Existing
development files were confirmed absent from the target home, so no one-time
cleanup was retained. ShellCheck was not available.
