# Project workspace simplification

Branch: feature/project-workspaces. Endpoint: verified local commits; no push or installation.

1. VS Code exact-depth directory discovery, without Git requirements.
2. Uniform terminal layouts; remove general and development-server special cases.
3. Shared discovery/checklist/state helpers, independent terminal selections; remove groups.
4. Stop all Archon-managed tmux sessions / dedicated Herdr session; remove kill.
5. Move VS Code under workspaces.
6. Finalize separate state paths under archon/workspaces; no migration or hardcoded selections.

Verify each commit with component tests, including isolated installation and syntax.
Run isolated real tmux integration checks for shutdown changes. Preserve unrelated sessions.

Step 1 complete: component suite, syntax, isolated installation and diff checks passed. ShellCheck unavailable.

Step 2a complete: removed development-server windows and commands. Uniform project layouts and rollback checks pass in the full component suite, including installation.

Step 3a complete: extracted shared discovery, terminal picker and atomic JSON helpers. VS Code behavior is unchanged; component suite including terminal and installation checks passed.

Steps 2b/3b complete: removed general and all groups, shared terminal checklist, independent saved selections. Replaced obsolete group/adapter tests with project behavior and real PTY coverage. All component, syntax and isolated installation checks passed; fixed trailing whitespace from removed adapter runner. Real tmux integration (2 cases) passed.

Step 4 complete: tag tmux sessions with @archon-managed, stop every tagged session regardless of disk/state, preserve untagged sessions, refuse untagged name collisions. Herdr stop now stops the dedicated archon session. Removed kill and old resource-filtering code. Full component checks passed; all 3 real tmux integration cases passed after correcting option commands to use session: targets.
