# Libraries command

Manage immediate Git repository directories under the fixed
`~/projects/personal/mrzli-jslib` root:

```sh
archon libs <command>
```

## Commands

- `build`: validate local `@mrzli-jslib/*` dependencies, install with Bun, and
  build packages in dependency order. Cycles and invalid local references fail
  before any package is built.
- `delete`: permanently delete every managed local repository after listing
  the targets and requiring confirmation. Use `--dry-run` to inspect them.
- `graph`: print direct dependencies between local packages.
- `prune`: delete repositories absent from the `mrzli-jslib` GitHub inventory,
  with inventory revalidation and the same confirmation safeguards. Use
  `--dry-run` to inspect them.
- `remote`: list repositories visible in the `mrzli-jslib` GitHub organization.
- `status`: show branch state, working-tree changes, stashes, and commits ahead.
  Add `--fetch` to refresh remote-tracking information first.
- `sync`: fetch and fast-forward clean repositories and clone missing
  repositories through GitHub CLI. Failures do not prevent remaining
  repositories from being processed.
- `help`: show global help or detailed help for one command.

```sh
archon libs build
archon libs status --fetch
archon libs prune --dry-run
archon libs help graph
```

Remote operations require GitHub CLI authentication. Builds use frozen Bun
installs without lifecycle scripts, followed by one explicit build per package.
