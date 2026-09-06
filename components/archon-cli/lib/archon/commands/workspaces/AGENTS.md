# Workspaces Command Instructions

- Keep lifecycle operations repeat-safe: starting an existing resource and
  stopping an absent resource must succeed without duplication.
- Report and skip missing configured directories.
- Preserve configured resource names, commands, and layouts unless explicitly
  asked to change them.
- Keep resource creation and rollback together; orchestration should report
  failures and continue where the command contract requires it.
- Use isolated fixtures and fake external operations; never disturb live
  sessions or launch real interactive tools during tests.
- Verify group selection, aggregate ordering, and failure propagation.
