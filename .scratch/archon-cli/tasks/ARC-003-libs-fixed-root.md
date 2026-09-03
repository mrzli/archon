# ARC-003: Decouple the libraries target from script location

Status: completed

Area: Libraries

Depends on: ARC-001

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Make the legacy libraries command operate on its fixed root so it can later
move without changing its target.

## Acceptance checklist

- [x] The target resolves to `~/projects/personal/mrzli-jslib` independently of script location.
- [x] Tests can inject a temporary home/root without affecting production defaults.
- [x] Deletion safety checks the exact resolved root rather than its basename.
- [x] All other command behavior and the legacy invocation remain unchanged.

## Verification

- Run the ARC-001 libraries checks.
- Run controlled `delete --dry-run` and `prune --dry-run` checks.
- Run `node --check` and `git diff --check`.

## Verification evidence

`libs.mjs` now derives its operation root from the current home directory, not
from `import.meta.url`, and compares the normalized operation root with the
exact required path before deletion. Its README documents the fixed root.

The baseline harness supplies an isolated `HOME` and executes the libraries
script from a separate `bin` directory. All four CLI baseline tests and all
seven existing tmux-workspace tests passed. Both Node scripts passed
`node --check`; the baseline harness passed `bash -n`; `git diff --check`
passed; and ShellCheck was unavailable.
