# Workspaces command

List configured projects or choose a backend explicitly to manage workspaces.
There is no default backend:

```bash
archon workspaces herdr start
archon workspaces tmux start
archon workspaces --help
```

`w` is an alias for `workspaces`. Backend aliases are `h` for `herdr` and `t`
for `tmux`; both work with `archon` and `arc`.

## Herdr

Requires Herdr on `PATH`, plus the tools used by the configured projects.
Manage workspaces in the dedicated Herdr session named `archon`:

```bash
arc w h start -g projects
arc w h stop
arc w h kill
arc w h --help
```

See [Herdr usage](./herdr/README.md) for prerequisites, options, and behavior.

## List

Show project paths under each workspace group without starting a backend:

```bash
archon workspaces list
arc w list -g projects
archon workspaces list --help
```

`-g` and `--group` select `current`, `general`, `jslibs`, `misc`, or `projects`.
Without a group, all groups appear alphabetically. Missing configured
directories are marked `(missing)`. JavaScript libraries are discovered from
local repositories, using the same selection as workspace startup; an empty
group shows `(no projects found)`. No Herdr or tmux installation is required.

Each workspace belongs to one primary group. `projects` contains `flashcards-fe`,
`flashcards-be`, `omarchy-lab`, `mrzli.github.io`, and `qt-market-chart`.
`misc` contains `archon`, `docs`, `js-templates`, `learning`, `repos`, and `skills`.
`general` provides the shell at `~/projects`, and `jslibs` contains the local
JavaScript library repositories.

`current` is a hardcoded selection from those groups: the general shell workspace,
`archon`, `learning`, `omarchy-lab`, `skills`, and `qt-market-chart`. It uses the
same workspaces, so starting a primary group and `current` does not create copies.

## tmux

Requires tmux on `PATH`, plus the tools used by the configured projects.
Manage the configured tmux session groups:

```bash
arc w t start -g projects
arc w t stop
arc w t kill
arc w t --help
```

See [tmux usage](./tmux/README.md) for options and behavior. `kill` stops the
entire tmux server, including sessions outside Archon's workspace groups.
