# ACTS-007: Finish TypeScript conversion and verify deployment

Status: planned

Depends on: ACTS-006

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Complete the migration and remove transitional allowances.

## Scope

CLI entry modules/barrels, build script, remaining JavaScript tests/helpers, final configurations, runners, instructions and documentation.

## Acceptance checklist

- [ ] Convert remaining CLI code and tests plus the named build function to TypeScript. Keep the explicit invocation and JavaScript launcher template.
- [ ] Audit all development modules and mixed suites for unconverted files and update every build-script reference after its rename.
- [ ] Remove allowJs and other temporary migration settings; enforce strict checking across all TypeScript source, tests, and build tooling.
- [ ] Ensure the final build emits only JavaScript runtime modules, launcher, and relative arc symlink (plus minimal metadata only if required by the recorded module contract).
- [ ] Confirm dist excludes TypeScript, declarations, tests, Markdown, build scripts, compiler files, lockfiles, node_modules, and stale output.
- [ ] Verify setup uses frozen dependencies and the checked build before copying the artifact; do not execute complete setup or add legacy cleanup.
- [ ] Update usage/prerequisites and reusable instructions. Add enduring operational documentation in docs without restoring deleted historical documents wholesale.
- [ ] Record final evidence and limitations; mark all task files, the index, and spec completed/archived only when their criteria are met.

## Verification

Run strict typecheck, the complete component suite, and the root suite in both stdin modes. Verify repeated builds, isolated type-error failure, fresh and repeated temporary installations, both executable aliases, and unrelated-file preservation. Confirm emitted JavaScript runs with Bun independently of source and development dependencies.

## Completion record

Not started. Record changes, commands/results, compatibility findings, and any
remaining limitations here when completing the task.
