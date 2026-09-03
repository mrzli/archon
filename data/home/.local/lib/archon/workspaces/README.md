# Workspaces command

Manage the existing tmux workspace launchers through the Archon CLI:

```bash
archon workspaces start
archon workspaces stop
archon workspaces start --group flashcards
archon workspaces stop -g jslibs
```

Without `--group` or `-g`, the command runs every group in the listed order for
start and reverse order for stop. Every group is attempted after a failure.
The command does not attach or switch tmux clients.

Flashcards, jslibs, and miscellaneous-project sessions are managed directly in
JavaScript. The legacy Bash launchers remain temporarily for rollback, but the
Archon command no longer invokes them or manages hub sessions.
