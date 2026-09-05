# Libraries Command Instructions

- Operate only on immediate Git repository directories beneath
  `~/projects/personal/mrzli-jslib`.
- Preserve dependency validation, cycle detection, and dependency-first build
  ordering for local `@mrzli-jslib/*` packages.
- Preserve frozen Bun installs without lifecycle scripts and one explicit build
  per package.
- Keep manifest, dependency-graph, and build-order policy in `src/build.mjs`,
  and GitHub response parsing in `src/github-inventory.mjs`; keep filesystem,
  Bun, and GitHub CLI execution in `src/libs.mjs`.
- Preserve deletion and prune dry-runs, cleanliness checks, confirmations, and
  remote-inventory revalidation.
- Keep command sections and README sections in alphabetical command order.
