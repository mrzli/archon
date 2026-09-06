# Archon CLI build and installation

The private package in `components/archon-cli` uses dependency-free Node.js
ECMAScript modules. Development modules live in `src/`; `bin/archon` is the
launcher template for the built installation layout.

Run `npm run build --prefix components/archon-cli`, or invoke
`node components/archon-cli/scripts/build.mjs` directly. No dependency
installation is needed. The build recreates only the component's ignored
`dist/` directory, stages runtime modules without Markdown documentation,
copies the executable launcher, and creates the relative `bin/arc -> archon`
symlink. It does not install anything into the home directory.

The artifact contains `dist/bin/archon`, `dist/bin/arc`, and `dist/lib/archon/`.
Run either built command directly for local use. `setup.sh` builds before
copying the contents of `dist/` into `~/.local/`, preserving executable
permissions and symlinks. The same artifact can be copied into another prefix;
preserve its `bin/` and `lib/` layout and put that prefix's `bin/` on `PATH`.
Installation overwrites corresponding managed runtime files and preserves
unrelated files under the existing overlay rules.

The component suite builds before testing. Focused module tests import source;
CLI integration tests execute the artifact. Repository integration checks
install the artifact into temporary homes and check repeated installation,
aliases, runtime imports, documentation exclusion, and unrelated-file
preservation. They simulate the scoped copy operations without running setup.

The build currently stages JavaScript without bundling or compilation. A future
TypeScript conversion can replace staging with JavaScript emission while
preserving the artifact and installation contract. Runtime selection and
development tooling are separate decisions; this change retains Node.js.
