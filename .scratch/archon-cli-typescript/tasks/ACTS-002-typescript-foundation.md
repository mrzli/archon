# ACTS-002: Introduce strict compilation and checked builds

Status: planned

Depends on: ACTS-001

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Establish the source-to-JavaScript pipeline with one small shared module.

## Scope

Package manifest and Bun lockfile, TypeScript configurations, build orchestration, setup dependency/build steps, test entry points and artifact checks, one shared module and its focused test.

## Acceptance checklist

- [ ] Add TypeScript and Bun type definitions as development dependencies and commit the generated lockfile.
- [ ] Add strict checking with temporary allowJs support. Separate runtime emission from checking tests and build tooling.
- [ ] Select and record compiler target, module resolution, import extensions, and verified tool versions. Demonstrate source tests and emitted runtime imports both resolve.
- [ ] Convert one small shared module and its focused test. Keep the remaining JavaScript working without weakening strictness for converted code.
- [ ] Emit only runtime modules into dist/lib/archon; retain the launcher and relative arc symlink. Adapt extension-sensitive installation assertions for transitional output.
- [ ] Make all production/test build entry points use the checked build. A type error must fail the build and prevent installation.
- [ ] Have setup install frozen-lockfile development dependencies in the component, then build, then copy dist. Preserve unrelated provisioning and repeat-safety.
- [ ] Update documented dependency installation, build, typecheck, and test commands.

## Verification

Run the shared checkpoint checks plus strict typecheck. In an isolated component copy, introduce a type error and assert a failing build does not reach a scoped install step. Verify frozen-lockfile installation and a copied artifact that has no source or node_modules alongside it.

## Completion record

Not started. Record changes, commands/results, compatibility findings, and any
remaining limitations here when completing the task.
