# Archon CLI: Bun runtime and TypeScript development

Status: in progress

Created: 2026-09-06

Implementation tasks: [Ordered task index](./tasks.md)

## Purpose

Move Archon CLI to Bun, then convert development code to strict TypeScript in
reviewable batches. Continue deploying a complete, JavaScript-only runtime
artifact from `dist/`. Every task must leave the CLI buildable and usable.
ACTS-001 and ACTS-002 are complete: execution uses Bun and checked builds emit
JavaScript from a mixed JavaScript/TypeScript source tree. The remaining conversion
batches are planned. See the task records for verified changes and results.

## Verified starting point (before ACTS-001)

- `components/archon-cli` is a private package with `build` and `test` scripts.
- Runtime modules live in `src/` as dependency-free Node.js ESM `.mjs` files.
- `scripts/build.mjs` uses a named build function, recreates `dist/`, copies
  runtime modules excluding Markdown, copies the executable `bin/archon`, and
  creates the relative `dist/bin/arc -> archon` symlink.
- The launcher uses a Node shebang and imports `../lib/archon/cli.mjs`.
- Setup already provisions Bun and invokes the Node build before copying the
  entire artifact into `~/.local/` with `rsync -a`.
- The component runner builds, runs Node tests and syntax checks, and runs
  `tests/test-workspaces-adapter.sh` using `tests/bin/tmux`.
- Root `tests/archon-cli/run.sh` adds build/installation integration checks,
  Bash syntax checks, optional ShellCheck, and whitespace validation.
- The retired migration script and its tests are absent. Do not restore them.
- Component instructions currently mandate Node and prohibit package
  dependencies. They must be updated as part of the authorized migration.

## Scope and invariants

Preserve CLI commands, aliases, help/error output, exit statuses, fixed roots,
subprocess arguments, destructive safeguards, dependency ordering, workspace
selection, rollback, and terminal attachment behavior. Preserve the existing
plain-function and object design and barrel conventions.

Keep runtime code free of third-party package dependencies. TypeScript and Bun
type definitions are development dependencies. Retain `node:*` APIs when they
work under Bun; replace an API only to resolve a demonstrated compatibility
problem. Do not add a cross-runtime abstraction or promise ongoing Node support.

No bundling, native executable compilation, package publishing, root workspace,
new command behavior, unrelated refactoring, or broad test rewrites belong in
this migration. Keep Bash integration scripts and fake executables in Bash.
Do not execute full setup or modify real home files as verification.

## Sequence

1. Switch JavaScript execution, build invocation, and test execution to Bun.
2. Introduce strict TypeScript configuration and JavaScript emission with a
   small converted shared module as proof of the complete pipeline.
3. Convert remaining shared modules, their tests, and shared test helpers.
4. Convert libraries command modules and tests.
5. Convert projects command modules and tests.
6. Convert workspaces command modules and tests.
7. Convert remaining CLI/build code, remove transitional configuration, and
   verify the final deployment contract.

These are sequential checkpoints. Convert tests alongside their production
modules; shared helpers may move earlier when a batch needs their types.
Record actual verification and any compatibility findings in each task file.

## Bun transition

Change the launcher to `#!/usr/bin/env bun` and run the build with Bun. Update
all production and test invocations, not just package scripts: setup, the
component runner, workspace adapter, and installation checks invoke the build
or executable directly today.

Adapt `node:test` usage to Bun's test runner while preserving assertions,
fixtures, environment restoration, and serialized execution where process-global
state is changed. Keep Node assertion APIs if compatible. Check runner discovery
explicitly so a passing command cannot silently omit suites. Do not assume Bun
accepts Node runner flags or implements every Node test API.

Replace Node-specific verification with Bun-appropriate checks; retain safe
Bash and whitespace validation. Exercise actual emitted/built CLI subprocesses,
not just source imports. Verify subprocess output/status handling, local Git,
terminal input, and aliases under Bun before introducing TypeScript.

## TypeScript and build contract

Use ordinary `.ts` development files and ESM JavaScript output, preserving
separate modules. Enable `strict` from the beginning. Temporarily permit
unconverted JavaScript with `allowJs`; do not require full checking of legacy
JavaScript before its batch. Remove this allowance at completion.

Provide a typecheck configuration that covers source, TypeScript tests, and the
build script as they convert. Use a build configuration that emits only runtime
source into `dist/lib/archon/`: tests and development scripts must never leak
into the deployment tree. Use TypeScript compilation for emission; Bun's runtime
TypeScript support does not substitute for type checking.

Choose and record module resolution, target, and import-extension settings in
the foundation task. Prove that the same imports work in Bun source tests and
in emitted JavaScript without access to source or development configuration.
Mixed `.mjs`/`.js` output may exist during migration; update imports and the
launcher as files convert. Final output is ESM JavaScript with explicit, valid
runtime import paths. Include minimal runtime package metadata only if needed
for the chosen resolution contract. Avoid path aliases and custom import-rewrite
machinery.

The build remains a named async function followed by an explicit invocation.
It typechecks, emits runtime JavaScript, copies the executable JavaScript
launcher, sets its executable permission, and creates the relative alias.
A typecheck/compiler error must produce a nonzero build exit; setup must not
install output from a failed build. Failed builds need not preserve the previous
local artifact, but must not be reported as successful.

The complete successful artifact is:

```text
dist/
├── bin/
│   ├── archon          # executable JavaScript, Bun shebang
│   └── arc -> archon   # relative symlink
└── lib/
    └── archon/         # emitted JavaScript modules
```

No `.ts`, declarations, tests, Markdown, compiler configuration, lockfile, or
`node_modules` belong in `dist/`. Source maps are outside initial scope. The
source launcher template remains JavaScript as an intentional exception to the
TypeScript development conversion.

## Type design

Type existing module boundaries, repository/package records, options, results,
and injected operations. Infer local types when clear. Keep domain types close
to their consumers; share types only when actually shared.

Treat untrusted JSON/external values as `unknown` at boundaries and narrow using
existing validation. Preserve supported inputs and failure behavior; type
migration is not authorization for new validation policy. Avoid blanket `any`,
`@ts-ignore`, or broad assertions that merely suppress errors. Document any
unavoidable narrow assertion. Test doubles must satisfy real dependency contracts
without accidentally falling back to production operations.

## Dependencies and setup

Add TypeScript and Bun type definitions as development dependencies and commit
the Bun lockfile. Before the first dependency installation, configure a three-day
minimum release age (259200 seconds) with no package exemptions in the component
bunfig.toml. Preserve this rule for all later resolutions; existing locked
versions are reused. Record the verified Bun/compiler versions in task evidence;
verify current official tool behavior when choosing exact configuration.

Setup must ensure Bun is available, install dependencies with the frozen lockfile
in the component directory (including development dependencies), run the checked
build, and only then copy `dist/` into `~/.local/`. A failed dependency install or
build must stop installation. Use the package's checked build entry point in
setup and tests so type checking cannot be bypassed accidentally.

Keep setup repeat-safe and preserve unrelated destination files. Do not add
one-time cleanup of previous `.mjs` files or paths to setup. Installations may
retain old overlay files under existing rules; fresh artifacts must be clean.
Do not remove Node provisioning needed by unrelated workstation tools.

The deployed CLI requires Bun and external commands used by its operations;
it does not require the TypeScript compiler or development dependencies.

## Verification and completion

At every checkpoint run focused tests, the full component suite, and root
installation checks. Run the full runner with terminal stdin and with stdin
redirected from `/dev/null`. From the foundation checkpoint onward include
strict type checking and compilation. Record discovered tests and results rather
than freezing a test count that may differ between runners.

Use temporary homes, local Git fixtures, and fake tmux/GitHub commands. Verify
repeat builds remove stale output, both commands execute, copied artifacts work
under a temporary prefix without source/development files, and repeated
installation preserves unrelated files. Add a focused isolated type-error check
that demonstrates build failure prevents the install phase; do not run setup.
The installation suite simulates scoped production copy operations, not the
entire workstation provisioning process.

For setup changes run `bash -n setup.sh`, ShellCheck when available, and
`git diff --check`; check changed Bash files individually. Update usage and
prerequisite documentation as each checkpoint changes them. Keep reusable rules
in AGENTS.md, not implementation inventories.

At completion, document enduring build/install operations in an appropriate
`docs/` page and usage in the relevant READMEs. Mark this spec and all tasks
completed/archived with actual evidence. Do not restore previously deleted
historical documentation wholesale.
