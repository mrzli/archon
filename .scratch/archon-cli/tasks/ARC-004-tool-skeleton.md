# ARC-004: Add the tool source skeleton

Status: completed

Area: CLI foundation

Depends on: ARC-002, ARC-003

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Create the prefix-shaped tool tree inside the home overlay and add the root
JavaScript command without routing existing tools yet.

## Acceptance checklist

- [x] `data/home/.local/bin` and `data/home/.local/lib/archon` exist in the specified layout.
- [x] Common and tool-specific `AGENTS.md` files have non-duplicative scopes.
- [x] `data/home/.local/bin/archon` is executable and uses a Node shebang.
- [x] Root help and invalid invocation behavior follow the specification.
- [x] Existing commands remain untouched.

## Verification

- Run `./data/home/.local/bin/archon --help` and invalid invocation checks.
- Run `node --check` on the entry point and modules.
- Run `git diff --check`.

## Verification evidence

Added the extensionless Node entry point, root dispatcher, and common plus
projects, libraries, and workspace instruction files under the prefix-shaped
`data/home/.local` tree. The root command currently implements only help and
invalid invocation behavior; existing tool entry points are unchanged.

All four root-command tests, all four projects/libraries baseline tests, and
all seven existing tmux-workspace tests passed. The entry point and module
passed `node --check`; the root test passed `bash -n`; `git diff --check`
passed; and ShellCheck was unavailable.
