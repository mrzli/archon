# Archon CLI Instructions

## Scope

- This tree contains the source installed as `~/.local/bin/archon` and
  `~/.local/lib/archon`.
- Use dependency-free Node.js ECMAScript modules, not Bun or npm packages.
- Keep fixed workstation paths derived from the current user's home directory.

## Code conventions

- Give domain command modules an explicit `main(arguments, context)` boundary;
  keep the root dispatcher at `main(arguments)`.
- Keep top-level executable behavior in `bin/archon`; imported modules must not
  execute commands as an import side effect.
- Wrap every `switch` case body, including `default`, in braces.
- Keep named commands alphabetical in routing, help, and documentation.
- Use `spawn` or `spawnSync` with argument arrays and no shell unless a command
  string is intentionally being sent to tmux.
- Keep terminal output concise and send usage errors to standard error.

## Verification

- Run `tests/archon-cli/run.sh` from the Archon repository for the complete
  focused CLI suite.
- Update the relevant README whenever command usage or behavior changes.
- Run `node --check` on every changed executable and `.mjs` module.
- Use temporary roots and fake external commands for destructive or
  workstation-mutating behavior.
- Run `git diff --check`.
