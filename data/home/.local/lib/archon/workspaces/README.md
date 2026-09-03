# Workspaces command

Manage the existing tmux workspace launchers through the Archon CLI:

```bash
archon workspaces start
archon workspaces stop
archon workspaces start --group flashcards
archon workspaces stop -g jslibs
```

Without `--group` or `-g`, the command runs every group and preserves the
current aggregate ordering, failure handling, and attach or switch behavior.
The selectable groups are `flashcards`, `jslibs`, and `misc-projects`.

Flashcards sessions are managed directly in JavaScript. Jslibs,
miscellaneous-project, and hub operations still delegate to the legacy Bash
launchers during migration. Hubs remain part of aggregate execution but cannot
be selected directly.
