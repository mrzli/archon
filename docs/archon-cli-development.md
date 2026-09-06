# Archon CLI development and deployment

The private package lives at `components/archon-cli` under the Archon root.
Source, tests, and build tooling use strict TypeScript. Bun executes development
tooling and the deployed JavaScript CLI. There are no third-party runtime packages.

## Build contract

Install the locked tooling and build from the repository root:

```bash
NODE_ENV=development bun install --frozen-lockfile --cwd components/archon-cli
bun run --cwd components/archon-cli build
```

The component's `bunfig.toml` requires newly resolved packages, including
transitive dependencies, to be at least three days old (259200 seconds), with
no exemptions. Frozen installs reuse the committed lockfile. TypeScript and Bun
type definitions are development dependencies; they are not deployed.

`scripts/build.ts` defines and explicitly invokes the named async `build`
function. It checks source, tests, and tooling with `tsconfig.json`, recreates
`dist`, emits only runtime source with `tsconfig.build.json`, and copies the
launcher with executable permissions and its relative alias. Errors stop the
build with a nonzero exit status. Run
`bun run --cwd components/archon-cli typecheck` to check without emitting.

Compilation uses strict checking, ES2022 output, NodeNext module resolution,
and explicit `.ts` relative source imports rewritten to `.js` during emission.
Bun runs the emitted ESM without a runtime package manifest. Modules remain
separate; there is no bundling, native compilation, or source-map output.

## Artifact and installation

The complete deployable tree is:

```text
dist/
├── bin/
│   ├── archon          # JavaScript launcher, #!/usr/bin/env bun
│   └── arc -> archon   # relative symlink
└── lib/archon/         # emitted .js modules
```

Only the launcher has a runtime shebang. It imports `../lib/archon/cli.js`;
modules under it have no shebang. `dist` excludes TypeScript, declarations,
tests, documentation, build tooling, compiler configuration, lockfiles, and
`node_modules`. Copy the entire tree with symlinks and permissions preserved,
not just the launcher.

`setup.sh` installs the component's frozen development dependencies, invokes the
checked build, then copies `dist/` into `~/.local/` with `rsync -a`. Dependency
or compilation failure stops CLI installation. `~/.local/bin` must be on `PATH`,
and Bun must be available there or elsewhere on `PATH`. The installed commands
need Bun and their external tools; they do not need the repository, compiler,
or development dependencies.

Installation updates managed CLI paths and preserves unrelated destination
files. It does not delete obsolete files from previous installations. Repeated
builds recreate a clean artifact; setup contains no one-time migration cleanup.

## Verification

```bash
bash tests/archon-cli/run.sh
bash tests/archon-cli/run.sh < /dev/null
```

Run the first command with terminal stdin. The runner builds and checks types,
runs each TypeScript suite in a separate Bun process, parses emitted JavaScript
and launchers, and exercises the Bash workspace adapter. Installation checks use
temporary homes and cover compilation failure in source/tests/tooling, repeat
builds, artifact contents, copied aliases, repeat-safe overlay installation, and
unrelated-file preservation. Bash syntax and available ShellCheck checks follow.

Tests use local fixtures and fake external operations. They do not run full
setup or alter real tmux sessions or home configuration. See the component and
command READMEs for usage and external-tool prerequisites.
