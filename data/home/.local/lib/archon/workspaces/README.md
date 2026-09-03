# Workspaces command

Manage the existing tmux workspace launchers through the Archon CLI:

```bash
archon workspaces start
archon workspaces stop
archon workspaces start --group flashcards
archon workspaces stop -g jslibs
```

Without `--group` or `-g`, the command runs every legacy group and preserves
the current aggregate ordering, failure handling, and attach or switch
behavior. The selectable groups are `flashcards`, `jslibs`, and
`misc-projects`. Hubs remain part of aggregate execution during migration but
cannot be selected directly.
