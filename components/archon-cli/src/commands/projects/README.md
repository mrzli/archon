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
- `prune`: delete repositories absent from the filtered GitHub inventory, with
  inventory revalidation and the same confirmation safeguards. Use `--dry-run`
  to inspect them.
- `remote`: list repositories owned by the authenticated GitHub user and owned
  organizations after configured exclusions.
- `status`: show branch state, working-tree changes, stashes, and commits ahead.
  Add `--fetch` to refresh remote-tracking information first.
- `sync`: fetch and fast-forward clean repositories and clone missing
  repositories over SSH. Failures do not prevent remaining repositories from
  being processed.
- `help`: show global help or detailed help for one command.

```sh
archon projects sync
archon projects status --fetch
archon projects prune --dry-run
archon projects help sync
```

Remote operations require GitHub CLI authentication. Organization and
`owner/repository` exclusions are matched case-insensitively.
