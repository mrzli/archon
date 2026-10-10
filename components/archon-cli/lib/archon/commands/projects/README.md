# Projects command

Manage Git repositories at the fixed
`~/projects/personal/<owner>/<repository>` layout:

```sh
archon projects <command>
```

Other files and directories under `~/projects/personal` are ignored.

## Commands

- `delete`: permanently delete every managed local repository after listing
  the targets and requiring confirmation. Use `--dry-run` to inspect them.
- `libs`: build or graph the `@mrzli-jslib/*` packages in
  `~/projects/personal/mrzli-jslib`. See [libraries](./libs/README.md).
- `prune`: delete repositories absent from the filtered GitHub inventory, with
  inventory revalidation and the same confirmation safeguards. Use `--dry-run`
  to inspect them.
- `remote`: list repositories owned by the authenticated GitHub user and owned
  organizations after configured exclusions.
- `secrets`: generate `.env` files from `.env.template` files and a central
  secrets store. See [secrets](./secrets/README.md).
- `status`: show branch state, working-tree changes, stashes, and commits ahead.
  Add `--fetch` to refresh remote-tracking information first. Exits with `1`
  when a repository cannot be inspected or has a warning, such as a missing
  upstream branch or a failed fetch; local changes alone do not affect it.
- `sync`: fetch and fast-forward clean repositories and clone missing
  repositories over SSH. Failures do not prevent remaining repositories from
  being processed. If the GitHub inventory cannot be listed, existing
  repositories are still updated, nothing is cloned, and the command exits
  with `1`.
- `help`: show global help or detailed help for one command.

```sh
archon projects sync
archon projects status --fetch
archon projects prune --dry-run
archon projects help sync
```

Remote operations require GitHub CLI authentication. Organization and
`owner/repository` exclusions are matched case-insensitively.
