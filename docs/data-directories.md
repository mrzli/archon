# Archon data directories

Archon keeps its data in one directory, `${XDG_DATA_HOME:-~/.local/share}/archon/`,
instead of several `archon-*` directories under `~/.local/share`:

- `repo/`: the bootstrap clone used on first boot. Afterwards, setup runs from
  `~/projects/personal/mrzli/archon`.
- `skills/`: the `mrzli/skills` checkout that setup links skills from.
- `secrets/secrets.env`: the store for `archon projects secrets`.

Configuration and state stay in their own XDG locations,
`${XDG_CONFIG_HOME:-~/.config}/archon` and `${XDG_STATE_HOME:-~/.local/state}/archon`.

Both workstations were migrated to this layout on 2026-10-10, and the migration
script was removed. Setup does not handle the old layout.
