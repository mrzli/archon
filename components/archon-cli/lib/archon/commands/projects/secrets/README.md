# Secrets command

Keep secret values in one local store and generate each project's `.env` file
from a committed template.

```sh
archon projects secrets <command>
```

The store is `${XDG_DATA_HOME:-~/.local/share}/archon-secrets/secrets.env`. It
holds one `NAME=value` entry per line. Blank lines and lines starting with `#`
are ignored, and values are used literally, without quoting or trimming. Only
names known to the CLI are allowed, currently `GITHUB_TOKEN`.

## init

Create the store with mode `600`, listing every allowed name with an empty
value, then fill in the values yourself. On an existing store, `init` appends
only the missing names and never changes existing entries.

```sh
archon projects secrets init
```

## sync

For every repository in `~/projects/personal/<owner>/<repository>` that has a
`.env.template` at its root, write `.env` with each `${NAME}` placeholder
replaced by the store value. Other `$` text is kept as written. The generated
file starts with a comment saying it is generated, has mode `600`, and is
overwritten whenever its content differs. Edit the template, not `.env`.

```sh
archon projects secrets sync
```

```text
created    mrzli/foo/.env
updated    mrzli/bar/.env
unchanged  mrzli/baz/.env
skipped    mrzli/qux/.env  (empty value: GITHUB_TOKEN)
```

A repository is skipped, leaving any existing `.env` as is, when its template
uses an unknown name or an empty value, or when `.env` is not ignored by Git.
Unknown names in the store produce a warning. `sync` refuses to run when the
store is missing or accessible by group or others, and exits with `1` when any repository
was skipped.

Example template:

```sh
GITHUB_TOKEN=${GITHUB_TOKEN}
PORT=3000
```
