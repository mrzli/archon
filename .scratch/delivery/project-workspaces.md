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
