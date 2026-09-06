# ACTS-007: Finish TypeScript conversion and verify deployment

Status: completed

Completed: 2026-09-06

Depends on: ACTS-006

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Complete the migration and remove transitional allowances.

## Scope

CLI entry modules/barrels, build script, remaining JavaScript tests/helpers, final configurations, runners, instructions and documentation.

## Acceptance checklist

- [x] Convert remaining CLI code and tests plus the named build function to TypeScript. Keep the explicit invocation and JavaScript launcher template.
- [x] Audit all development modules and mixed suites for unconverted files and update every build-script reference after its rename.
- [x] Remove allowJs and other temporary migration settings; enforce strict checking across all TypeScript source, tests, and build tooling.
- [x] Ensure the final build emits only JavaScript runtime modules, launcher, and relative arc symlink (plus minimal metadata only if required by the recorded module contract).
- [x] Confirm dist excludes TypeScript, declarations, tests, Markdown, build scripts, compiler files, lockfiles, node_modules, and stale output.
- [x] Verify setup uses frozen dependencies and the checked build before copying the artifact; do not execute complete setup or add legacy cleanup.
- [x] Update usage/prerequisites and reusable instructions. Add enduring operational documentation in docs without restoring deleted historical documents wholesale.
- [x] Record final evidence and limitations; mark all task files, the index, and spec completed/archived only when their criteria are met.

## Verification

Run strict typecheck, the complete component suite, and the root suite in both stdin modes. Verify repeated builds, isolated type-error failure, fresh and repeated temporary installations, both executable aliases, and unrelated-file preservation. Confirm emitted JavaScript runs with Bun independently of source and development dependencies.

## Completion record

ACTS-006 was committed as `b9cf375` before this checkpoint. ACTS-007 is
implemented in the working tree, ready for the final implementation commit.

Converted the CLI entry, command barrel, and build script to `.ts`. The build
still defines and explicitly invokes its named async function. All source,
tests, helpers, and tooling are now TypeScript; the intentional JavaScript
launcher imports emitted `cli.js` and is the only runtime file with a shebang.
Removed allowJs/checkJs and legacy test discovery. Strict checking covers all
three development trees; syntax checks cover the launcher and emitted JavaScript.
Updated every live build-script reference, including setup and Bash adapters.

The final artifact contains `.js` runtime modules, executable `bin/archon`, and
relative `bin/arc -> archon`. Strengthened artifact checks to reject legacy module
extensions, development directories, and unexpected symlinks. Extended the
isolated compilation-failure check to build tooling as well as source/tests.
Copied aliases run with the temporary home as their working directory, without
source, package metadata, compiler configuration, or development dependencies
in the installation. Bun resolves the emitted ESM successfully.

Setup retains frozen dependency installation in the component directory before
the checked build and overlay copy, under its existing exit-on-error behavior.
Only the build-script extension changed; no legacy cleanup or workstation
mutation was added. The three-day release-age policy and lockfile are unchanged.

Updated usage/prerequisites and reusable component instructions. Enduring build,
module-resolution, artifact, installation, and verification knowledge is recorded
in [the development/deployment documentation](../../../docs/archon-cli-development.md).

Verification with Bun 1.4.1 and TypeScript 7.0.2:

- `bun run --cwd components/archon-cli typecheck` and `build` passed.
- The complete root runner passed with terminal stdin and `/dev/null` stdin:
  129 tests across 18 files, five workspace adapter cases, and three installation
  cases in each mode. The component suite runs within each full check.
- Checked source/test/tooling type errors stop installation, repeat builds remove
  stale output and reproduce the same file checksums, artifact contents exclude
  development files, both aliases run after copying, repeat overlay installs
  converge, and unrelated files survive.
- All Bash syntax checks (including setup), Bun parsing, and git diff whitespace
  checks passed. ShellCheck is unavailable.
- Audited source/tests/scripts for remaining `.mjs`/`.js` development modules and
  live paths for old build/CLI references; none remain. Historical scratch records
  retain the paths that applied at their checkpoint.

All seven migration checkpoints are complete. Full setup and installation into
real home paths were not run; integration verification uses isolated fixtures.
External account operations and live tmux sessions were not exercised. Old files
in existing installations remain subject to the documented non-deleting overlay
policy, while fresh build artifacts are clean.
