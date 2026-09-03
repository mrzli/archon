# ARC-013: Add home-overlay ignores

Status: proposed

Area: Installation

Depends on: ARC-006, ARC-007, ARC-012

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Teach the shared home-overlay copy operation to exclude development-only files.

## Acceptance checklist

- [ ] One repository-wide ignore list contains paths relative to `data/home`.
- [ ] Setup changes from plain `cp -a` only in this task and honors the list.
- [ ] Rules target Archon tool `AGENTS.md`, READMEs, and tests specifically.
- [ ] Previously copied excluded files are removed by exact managed paths.
- [ ] Runtime files and unrelated home-overlay files continue to copy normally.
- [ ] The operation remains repeat-safe and preserves unrelated destination files.

## Verification

- Copy twice into a temporary home containing previously copied development
  files and unrelated files; compare the resulting tree.
- Run `bash -n setup.sh`, ShellCheck when available, and `git diff --check`.
