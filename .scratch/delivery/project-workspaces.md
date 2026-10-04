# Project workspace simplification

Status: complete.

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

Step 5 complete: VS Code now routes only under workspaces, using visual-studio-code/vsc. Moved its implementation and usage README alongside the other backends. Executable aliases, VS Code window behavior, component suite and isolated installed routing passed.

Step 6 complete: all selections now use separate files under archon/workspaces. Older files are ignored and preserved. Full component, syntax and isolated installation verification passed, including actual interactive installed starts through archon and arc.

Final self-review complete: removed obsolete option-parser bookkeeping, unused
backend fields/injection and a single-use creation wrapper. Removed outdated Git
fixture setup and test prerequisites. No blocking findings remain.

Final verification: `bash tests/test.sh` passed (setup checks use isolated
fixtures, CLI suite includes real PTYs and isolated installation), plus all 3
cases in `bash components/archon-cli/tests/run-integration.sh`. Ruby/Bash syntax
and `git diff --check` passed. ShellCheck unavailable. VS Code/Herdr external
operations are verified with fakes; real tmux checks use temporary sockets.

No hardcoded project selections, state migration or old-path fallback. No real
home installation, push or merge performed. All requested work is committed.

## Follow-up: kill and names

Status: complete. Restored kill for every running Herdr session / the entire
current tmux server, then simplified Herdr workspace labels to exact folder
names. VS Code is unchanged. Each part is committed separately.

Herdr 0.8.2 allows duplicate workspace labels; its workspace list does not expose
project directories. Keep a project-path-to-workspace-ID map in the existing
Herdr selection file and preserve it across selection changes. Adopt and rename
selected workspaces with earlier Archon labels without recreating them. Missing
IDs are replaced when the workspace is recreated; ID-save failures roll back
new resources. tmux requires unique names, so its existing names are retained.

Verification: full CLI/component and isolated installation checks passed after
both changes. All four isolated real tmux integration cases passed for kill,
including shutdown from the calling pane and preservation of another server.
Herdr checks use fakes and the installed CLI help / official v0.8.2 source, not
live sessions. ShellCheck unavailable. No installation, push or merge performed.
