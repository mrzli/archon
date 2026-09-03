# ARC-004: Add the tool source skeleton

Status: proposed

Area: CLI foundation

Depends on: ARC-002, ARC-003

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Create the prefix-shaped tool tree inside the home overlay and add the root
JavaScript command without routing existing tools yet.

## Acceptance checklist

- [ ] `data/home/.local/bin` and `data/home/.local/lib/archon` exist in the specified layout.
- [ ] Common and tool-specific `AGENTS.md` files have non-duplicative scopes.
- [ ] `data/home/.local/bin/archon` is executable and uses a Node shebang.
- [ ] Root help and invalid invocation behavior follow the specification.
- [ ] Existing commands remain untouched.

## Verification

- Run `./data/home/.local/bin/archon --help` and invalid invocation checks.
- Run `node --check` on the entry point and modules.
- Run `git diff --check`.
