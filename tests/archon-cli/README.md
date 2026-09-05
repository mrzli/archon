# Archon CLI tests

Run the complete suite from the repository root:

```bash
tests/archon-cli/run.sh
```

Test behavior at the lowest layer that fully protects the contract:

- `*-cli.test.mjs` covers command wiring, output, and external command
  construction with temporary homes and fake executables.
- Focused module tests cover validation, ordering, and workflow policy
  directly. Do not repeat those cases through the CLI unless the command
  boundary adds behavior.
- `*-missing-root.test.mjs` keeps the empty-state regression matrix explicit.
- `repository-status.test.mjs` exercises the shared inspection behavior with
  temporary real Git repositories.
- Workspace module tests remain beside the workspace sources.
- Shell tests are reserved for Bash-owned installation and migration behavior,
  plus the fake-tmux end-to-end adapter check.

Tests must not use the real home directory, GitHub account, or tmux server.
