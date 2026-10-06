# Libraries command

Build the JavaScript packages in `~/projects/personal/mrzli-jslib`. Clone and
update them with `archon projects sync`, like any other project.

```sh
archon projects libs <command>
```

## Commands

- `build`: validate local `@mrzli-jslib/*` dependencies, install with Bun, and
  build packages in dependency order. Cycles and invalid local references fail
  before any package is built.
- `graph`: print direct dependencies between local packages.
- `help`: show libs help or detailed help for one command.

```sh
archon projects libs build
archon projects libs graph
archon projects libs help build
```

Builds use frozen Bun installs without lifecycle scripts, followed by one
explicit build per package.
