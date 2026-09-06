# ACTS-002: Introduce strict compilation and checked builds

Status: completed

Completed: 2026-09-06

Depends on: ACTS-001

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Establish the source-to-JavaScript pipeline with one small shared module.

## Scope

Package manifest and Bun lockfile, TypeScript configurations, build orchestration, setup dependency/build steps, test entry points and artifact checks, one shared module and its focused test.

## Acceptance checklist

- [x] Add TypeScript and Bun type definitions as development dependencies and commit the generated lockfile.
- [x] Add strict checking with temporary allowJs support. Separate runtime emission from checking tests and build tooling.
- [x] Select and record compiler target, module resolution, import extensions, and verified tool versions. Demonstrate source tests and emitted runtime imports both resolve.
- [x] Convert one small shared module and its focused test. Keep the remaining JavaScript working without weakening strictness for converted code.
- [x] Emit only runtime modules into dist/lib/archon; retain the launcher and relative arc symlink. Adapt extension-sensitive installation assertions for transitional output.
- [x] Make all production/test build entry points use the checked build. A type error must fail the build and prevent installation.
- [x] Have setup install frozen-lockfile development dependencies in the component, then build, then copy dist. Preserve unrelated provisioning and repeat-safety.
- [x] Update documented dependency installation, build, typecheck, and test commands.

## Verification

Run the shared checkpoint checks plus strict typecheck. In an isolated component copy, introduce a type error and assert a failing build does not reach a scoped install step. Verify frozen-lockfile installation and a copied artifact that has no source or node_modules alongside it.

## Completion record

ACTS-001 was committed as `d7ee1e2` before this task began. This checkpoint is
implemented in the working tree, including the generated `bun.lock`, ready for
the next implementation commit.

Before installing anything, added component `bunfig.toml` with the user-requested
`minimumReleaseAge = 259200` and `minimumReleaseAgeExcludes = []`. Resolution
under Bun 1.4.1 selected TypeScript 7.0.2 and @types/bun 1.4.0, saved as exact
development dependencies. The lockfile records their transitive dependencies and
integrities. Frozen-lockfile installation completed without changes. The first
sandboxed installation failed on Bun's temporary-directory access; installation
then succeeded with approved access from the component directory.

Compiler decisions:

- ES2022 target, NodeNext module/module resolution, explicit Bun ambient types,
  strict checking, and native `rewriteRelativeImportExtensions`.
- Source-relative `.ts` imports are valid for Bun source execution; TypeScript
  rewrites them to `.js` in emitted modules, including imports in legacy `.mjs`.
- Base configuration checks source, tests, and scripts without emission. Temporary
  allowJs/checkJs=false permits legacy JavaScript while converted TypeScript is
  strict. Build configuration emits only src, with noEmitOnError, into
  dist/lib/archon. No declaration files or source maps are emitted.
- Bun executes mixed `.mjs`/`.js` ESM output without additional package metadata,
  verified by the installed launcher in an isolated temporary home.

Converted shared argument helpers to TypeScript, adding explicit string,
readonly argument-array, callback, and boolean types. Updated their sibling and
barrel imports. Converted the existing exit-status/usage suite to TypeScript
without changing its bodies or assertions; it already covers these helpers
through real command invocations. No redundant helper-only tests were added.
Other source-import tests also exercise the typed helpers through shared barrels.

The named build function now runs the locally installed compiler with Bun for
whole-project checking, then runtime emission, before assembling the launcher
and alias. Direct script invocation remains checked, so all existing setup and
test callers share the same gate. Setup installs frozen-lockfile development
dependencies with NODE_ENV=development before invoking the build and copying
its artifact. Dependency scanning for Bash verification skips node_modules.

Verification:

- `bun run --cwd components/archon-cli typecheck` and `build` passed.
- `NODE_ENV=development bun install --frozen-lockfile` in the component passed
  without changing package state or the lockfile.
- Complete root verification passed with terminal stdin and `/dev/null`: 129
  tests across the same 18 files, five workspace integration cases, and three
  build/install cases. Discovery covers both `.test.mjs` and `.test.ts`.
- An isolated component copy with a source type error, then a test type error,
  produced TS2322 and failed before artifact generation and the scoped install
  phase. The fixture links compiler dependencies only; it does not touch setup
  or the working source. This tests build/install sequencing, not full setup.
- Clean repeated emission, stale-output removal, JavaScript-only artifact checks,
  both launcher/alias paths, and repeated installation/data preservation passed.
  Fresh installed copies run without source, compiler config, or node_modules.
- The converted usage/exit-status test is byte-identical apart from its filename.
  TOML validation confirmed 259200 seconds and no exemptions.
- Bun parsing, Bash syntax (including setup), and whitespace checks passed.
  ShellCheck was unavailable. No full provisioning or real home installation ran.

READMEs now document dependency installation, checked builds, type checking,
and release-age behavior. Contributor rules preserve the age policy and require
strict checks for converted code. ACTS-003 through ACTS-007 remain planned.

References: [TypeScript import-extension rewriting](https://www.typescriptlang.org/tsconfig/rewriteRelativeImportExtensions.html)
and [Bun minimum release age](https://bun.com/docs/pm/cli/install#minimum-release-age).
The latter applies to new direct/transitive resolutions, not revalidation of
already locked versions.
