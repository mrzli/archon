# Project Instructions

## Project boundaries

- The orchestrator's code and documentation are the direct files in this
  directory: `projects.mjs`, `README.md`, and `AGENTS.md`.
- Treat every child directory as managed project data. Do not modify files
  inside those directories unless the user explicitly requests it.
- Immediate child directories group repositories by GitHub owner or
  organization. Only Git repository roots at `<owner>/<repository>` are
  managed; ignore all other entries.
- Discover remote repositories from the authenticated GitHub user and owned
  organizations. Preserve GitHub API pagination and validate organization and
  repository blacklists before using a remote inventory.

## `projects.mjs` conventions

- The script runs with Node.js, not Bun.
- Keep the entry point near the top: define `main()`, call `main()`, and place
  the functions it uses below it where practical.
- Keep top-level executable code limited to the `main()` call. Imports,
  constants, and function declarations may remain at the top level.
- Wrap every `switch` case body, including `default`, in braces.
- When multiple cases have identical behavior, use fallthrough and put the
  shared braced body on only the final case in that group.
- Order named commands alphabetically in the command switch, command-specific
  function sections, help output, and README command sections. Keep help
  aliases after named commands and `default` last.
- Add visible comment dividers naming each command-specific function section.
- Keep helpers used by multiple commands in a final `Shared utilities`
  section.
- Format multiline help text as one source string per output line and join the
  lines, preserving readable terminal output without an unwieldy multiline
  string in the source.
- Keep terminal output concise. Identify the owner or organization when
  displaying repositories, and align comparable columns or suffixes when that
  makes multi-repository output easier to scan.

## Documentation and verification

- Update `README.md` whenever command usage or behavior changes, preserving the
  same command order as the script.
- Run `node --check projects.mjs` after changing the script.
- Use `node ./projects.mjs delete --dry-run` when testing deletion behavior.
- Use `node ./projects.mjs prune --dry-run` when testing pruning behavior.
- Never run a real deletion or prune unless the user explicitly requests the
  deletion itself.
