# Workspaces Command Instructions

- Keep tmux operations repeat-safe: starting an existing session and stopping
  an absent session must succeed without duplication.
- Report and skip missing configured project directories.
- Preserve configured session names, windows, commands, and layouts unless a
  task explicitly changes them.
- Test only with temporary project roots and fake tmux state; never disturb the
  user's real tmux server or launch real editor, Codex, or development commands.
- Verify named groups and aggregate ordering and failure propagation.
