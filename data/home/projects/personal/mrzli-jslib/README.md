# `mrzli-jslib` local development orchestrator

The terminal script is [`libs.mjs`](./libs.mjs). Run it directly from this directory; its shebang selects Node.js.

Use either form to show detailed help for a command:

```sh
./libs.mjs help <command>
./libs.mjs <command> --help
```

## Build local packages

Install and build every local `@mrzli-jslib/*` package in dependency order:

```sh
./libs.mjs build
```

Before running Bun, the command validates every local package reference and build script, detects dependency cycles, and determines an order in which dependencies are built before their dependents. A cycle or other validation error stops the command before any package is installed or built.

For each package in that order, the command runs:

```sh
bun install --frozen-lockfile --ignore-scripts
bun run build
```

The frozen install fails rather than changing a lockfile that disagrees with its `package.json`. Lifecycle scripts are suppressed during installation so each package's `prepare` script does not build it implicitly; the explicit build therefore runs exactly once. The command stops at the first install or build failure.

## Delete local repositories

Permanently delete every immediate child directory that contains a Git repository:

```sh
./libs.mjs delete
```

The command lists every target, silently performs the same non-fetching inspection as the `status` command, and requires you to type `delete` before anything is removed. It refuses to run unless the script itself is inside a directory named exactly `mrzli-jslib`.

If any repository has staged, unstaged, or untracked changes, stash entries, commits ahead, status warnings, or an inspection error, it is considered unclean. After the normal confirmation, deleting any unclean repositories requires typing `delete` a second time.

To inspect the targets without deleting anything or prompting for confirmation:

```sh
./libs.mjs delete -n
./libs.mjs delete --dry-run
```

Deletion is permanent and includes uncommitted, ignored, and untracked files inside each repository. It deletes local directories only; it does not delete repositories from GitHub.

## Show the local dependency graph

Show the dependencies between local `@mrzli-jslib/*` packages:

```sh
./libs.mjs graph
```

Each package is shown on its own line, followed by one indented arrow for each direct local dependency. Packages without local dependencies have nothing printed beneath them.

The command reads `dependencies`, `devDependencies`, `optionalDependencies`, and `peerDependencies`. Every dependency whose name starts with `@mrzli-jslib/` must use a direct local `file:` reference, for example:

```json
{
  "dependencies": {
    "@mrzli-jslib/numeric": "file:../numeric"
  }
}
```

The referenced directory must be one of the local repositories and its package name must match the dependency name. An invalid protocol, missing path, or name mismatch causes the command to fail instead of producing an incomplete graph.

## Prune obsolete local repositories

Delete local repositories whose directory names no longer appear in the `mrzli-jslib` GitHub organization:

```sh
./libs.mjs prune
```

The command refuses to proceed unless it can retrieve a complete remote inventory and the script is inside a directory named exactly `mrzli-jslib`. It lists the candidates, silently inspects their Git state, and requires typing `delete`. If any candidate is unclean, it requires typing `delete` a second time. Immediately before deletion, it retrieves the remote inventory again and aborts if a candidate has reappeared.

Inspect the candidates without prompting or deleting anything:

```sh
./libs.mjs prune -n
./libs.mjs prune --dry-run
```

## List remote repositories

This command lists every repository owned by the `mrzli-jslib` GitHub organization that is visible to the currently authenticated GitHub CLI account:

```sh
./libs.mjs remote
```

Private and archived repositories are marked with `(private)` and `(archived)` after their names.

It requires GitHub CLI to be installed and authenticated:

```sh
gh auth login
```

The command only reads remote repository information. It does not change local or remote repositories.

## Show local repository status

Show one concise line of Git state for every local repository:

```sh
./libs.mjs status
```

Each line includes the checked-out branch, staged, unstaged, and untracked file counts, the stash count, and commits ahead across every local branch. Branches without an upstream are identified explicitly when they contain commits that are not present on any remote-tracking branch.

By default, the command uses the existing local remote-tracking information. Refresh it before reporting with:

```sh
./libs.mjs status --fetch
```

The `--fetch` option runs `git fetch --all --prune` in each repository. A fetch or inspection failure is reported on that repository's line and causes a non-zero exit code without preventing other repositories from being inspected.

## Synchronize repositories

Update existing local repositories and clone remote repositories that are missing locally:

```sh
./libs.mjs sync
```

The command reports progress before starting each repository so long-running fetches and clones remain visible.

For each repository, the command runs `git fetch --all --prune`, then fast-forwards the checked-out branch from its configured upstream. It never creates a merge commit or rebases local commits. A divergent branch is reported as an error and left unchanged.

Fetching still occurs when the working tree has changes, but the checked-out branch is only fast-forwarded when there are no staged, unstaged, or untracked changes. Detached heads, missing upstreams, fetch failures, and update failures are reported without preventing other repositories from being processed.

The command retrieves the repository list from the `mrzli-jslib` GitHub organization and clones every repository whose name does not match an existing local Git repository directory. Private repositories are supported through the authenticated GitHub CLI account. A cloning failure is reported without preventing other repositories from being processed.

## Show help

Show the command list:

```sh
./libs.mjs help
```

Show help for one command:

```sh
./libs.mjs help status
./libs.mjs status --help
```

Both command-specific forms produce the same output.
