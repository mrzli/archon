# ACT-004: Test shared production installation operations

Status: pending

Area: CLI installation and layout tests

Depends on: ACT-003

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Outcome

Make setup and installation tests use the same narrowly scoped copying and managed-library replacement implementation.

## Expected files

`setup.sh`, `tests/archon-cli/test-install-layout.sh`, the new scoped installation implementation, and managed-directory configuration only if required.

## Acceptance checklist

- [ ] Inspect the existing replacement phase and choose the smallest extraction covering runtime copying and managed-library replacement.
- [ ] Pass explicit source and destination paths so tests can install into temporary homes.
- [ ] Have setup and tests invoke the shared operations; remove duplicated installation behavior from the tests.
- [ ] Keep one replacement policy and preserve setup logging and repeat-safe behavior.
- [ ] Verify first and repeated installation converge on the intended runtime layout.
- [ ] Seed a stale module and let the production replacement operation remove it; do not delete it in test preparation.
- [ ] Verify unrelated sibling libraries and other unmanaged home files survive.
- [ ] Verify executable entry point, resolvable runtime imports, and relative `arc -> archon` shortcut with equivalent help.
- [ ] Exclude development instructions, documentation, and tests from the installed runtime.
- [ ] Keep overlay-only preservation checks distinct from managed-directory replacement checks.
- [ ] Do not add legacy cleanup or one-time migrations to setup, including removal of `a`.
- [ ] Ensure the syntax runner includes any new shell scripts.

## Verification

- Run installation tests using temporary destinations, including repeat-install, stale-module, and preservation cases.
- Run `bash -n setup.sh`, syntax checks for new scripts, and ShellCheck when available.
- Run the canonical suite; never execute full workstation setup or install into the real home.

