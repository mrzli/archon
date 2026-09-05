# ACT-004: Test shared production installation operations

Status: reverted at user request

Reverted: 2026-09-06. The extraction was judged too broad for the test benefit.
Home installation remains in `setup.sh`, and layout tests retain their original
simulation. The completed checklist below records the implementation before
reversion; it does not describe the current code.

Area: CLI installation and layout tests

Depends on: ACT-003

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Outcome

Make setup and installation tests use the same narrowly scoped copying and managed-library replacement implementation.

## Expected files

`setup.sh`, `tests/archon-cli/test-install-layout.sh`, the new scoped installation implementation, and managed-directory configuration only if required.

## Acceptance checklist

- [x] Inspect the existing replacement phase and choose the smallest extraction covering runtime copying and managed-library replacement.
- [x] Pass explicit source and destination paths so tests can install into temporary homes.
- [x] Have setup and tests invoke the shared operations; remove duplicated installation behavior from the tests.
- [x] Keep one replacement policy and preserve setup logging and repeat-safe behavior.
- [x] Verify first and repeated installation converge on the intended runtime layout.
- [x] Seed a stale module and let the production replacement operation remove it; do not delete it in test preparation.
- [x] Verify unrelated sibling libraries and other unmanaged home files survive.
- [x] Verify executable entry point, resolvable runtime imports, and relative `arc -> archon` shortcut with equivalent help.
- [x] Exclude development instructions, documentation, and tests from the installed runtime.
- [x] Keep overlay-only preservation checks distinct from managed-directory replacement checks.
- [x] Do not add legacy cleanup or one-time migrations to setup, including removal of `a`.
- [x] Ensure the syntax runner includes any new shell scripts.

## Verification

- Run installation tests using temporary destinations, including repeat-install, stale-module, and preservation cases.
- Run `bash -n setup.sh`, syntax checks for new scripts, and ShellCheck when available.
- Run the canonical suite; never execute full workstation setup or install into the real home.

Completed: 2026-09-06. Extracted the existing home-installation phase into
`scripts/install-home.sh`, preserving default overlay and optional replacement.
Setup and layout tests invoke the same implementation. Repeat installs, paths
with spaces, production stale-module removal, runtime layout, and unrelated-file
preservation passed. The full suite and individual Bash checks passed;
ShellCheck was unavailable. Full setup was not executed.
