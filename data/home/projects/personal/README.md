# Personal project orchestrator

The terminal script is [`projects.mjs`](./projects.mjs). Run it with Node.js
from this directory.

Local repositories use exactly this layout:

```text
personal/<owner>/<repository>
```

The immediate child directories group repositories by GitHub owner or
organization. Only Git repository roots exactly two levels below this
directory are managed. Other files and directories are ignored and left
untouched; this includes owner-level project-management files.

Use either form to show detailed help for a command:

```sh
node ./projects.mjs help <command>
node ./projects.mjs <command> --help
```

## Repository discovery and exclusions

Remote commands include repositories owned by the authenticated GitHub user
and repositories owned by organizations that user administers.

Organizations can be excluded with `ORGANIZATION_BLACKLIST` in
`projects.mjs`. Individual repositories can be excluded with
`REPOSITORY_BLACKLIST`, using canonical `owner/repository` names. Blacklist
entries are validated before use and matched case-insensitively.

## Delete local repositories

Permanently delete every local Git repository found at
`<owner>/<repository>`:

```sh
node ./projects.mjs delete
```

The command lists every target, silently performs the same non-fetching
inspection as the `status` command, and requires you to type `delete` before
anything is removed. It refuses to run unless the script itself is inside a
directory named exactly `personal`.

If any repository has staged, unstaged, or untracked changes, stash entries,
commits ahead, status warnings, or an inspection error, it is considered
unclean. After the normal confirmation, deleting any unclean repositories
lists each reason and requires typing `delete` a second time.

To inspect the targets without deleting anything or prompting for
confirmation:

```sh
node ./projects.mjs delete -n
node ./projects.mjs delete --dry-run
```

Deletion is permanent and includes uncommitted, ignored, and untracked files
inside each repository. It deletes local directories only; it does not delete
repositories from GitHub. Owner and organization directories, along with the
orchestrator's direct files, are not deleted.

## Prune obsolete local repositories

Delete local repositories whose canonical `owner/repository` names no longer
appear in the included remote inventory:

```sh
node ./projects.mjs prune
```

The command refuses to proceed unless it can retrieve every complete remote
inventory and the script is inside a directory named exactly `personal`. It
lists the candidates, silently inspects their Git state, and requires you to
type `delete`. If any candidate is unclean, it requires typing `delete` a
second time. Immediately before deletion, it retrieves the remote inventories
again and aborts if a candidate has reappeared.

Repositories covered by either blacklist are ignored by `prune`; exclusion
does not make an existing local repository obsolete.

Inspect the candidates without prompting or deleting anything:

```sh
node ./projects.mjs prune -n
node ./projects.mjs prune --dry-run
```

## List remote repositories

List included repositories owned by the authenticated GitHub user or an
organization owned by that user:

```sh
node ./projects.mjs remote
```

Each repository is identified as `owner/repository`. Non-public visibility and
archived state are shown after the name.

The command requires GitHub CLI to be installed and authenticated:

```sh
gh auth login
```

It only reads remote repository information. It does not change local or
remote repositories.

## Show local repository status

Show one concise line of Git state for every managed local repository:

```sh
node ./projects.mjs status
```

Each line identifies the owner or organization and repository, then shows the
checked-out branch, staged, unstaged, and untracked file counts, the stash
count, and commits ahead across every local branch. Branches without an
upstream are identified explicitly when they contain commits that are not
present on any remote-tracking branch.

By default, the command uses the existing local remote-tracking information.
Refresh it before reporting with:

```sh
node ./projects.mjs status --fetch
```

The `--fetch` option runs `git fetch --all --prune` in each repository. A fetch
or inspection failure is reported on that repository's line and causes a
non-zero exit code without preventing other repositories from being
inspected.

## Synchronize repositories

Update existing local repositories and clone remote repositories that are
missing locally:

```sh
node ./projects.mjs sync
```

The command reports each GitHub discovery stage as it starts, then prints
progress and the result for each repository as it is synchronized.

For each existing repository, the command runs `git fetch --all --prune`, then
fast-forwards the checked-out branch from its configured upstream. It never
creates a merge commit or rebases local commits. A divergent branch is
reported as an error and left unchanged.

Fetching still occurs when the working tree has changes, but the checked-out
branch is only fast-forwarded when there are no staged, unstaged, or untracked
changes. Detached heads, missing upstreams, fetch failures, and update failures
are reported without preventing other repositories from being processed.

The command uses the filtered GitHub inventory described above and clones each
missing repository over SSH into its corresponding `<owner>/<repository>`
directory. It creates a missing owner directory but refuses to overwrite an
existing non-repository destination. Private repositories are supported
through the authenticated GitHub and SSH configuration. A cloning failure is
reported without preventing other repositories from being processed.

## Show help

Show the command list:

```sh
node ./projects.mjs help
```

Show help for one command:

```sh
node ./projects.mjs help status
node ./projects.mjs status --help
```

Both command-specific forms produce the same output.
