# Project Instructions

## `libs.mjs` conventions

- The script runs with Node.js, not Bun.
- Keep the entry point near the top: define `main()`, call `main()`, and place the functions it uses below it where practical.
- Keep top-level executable code limited to the `main()` call. Imports, constants, and function declarations may remain at the top level.
- Wrap every `switch` case body, including `default`, in braces.
- When multiple cases have identical behavior, use fallthrough and put the shared braced body on only the final case in that group.
- Order named commands alphabetically in the command switch, command-specific function sections, help output, and README command sections. Keep help aliases after named commands and `default` last.
- Add visible comment dividers naming each command-specific function section.
- Keep helpers used by multiple commands in a final `Shared utilities` section.
- Format multiline help text as one source string per output line and join the lines, preserving readable terminal output without an unwieldy multiline string in the source.
- Keep terminal output concise. Align comparable columns or suffixes when that makes multi-repository output easier to scan.

## Documentation and verification

- Update `README.md` whenever command usage or behavior changes, preserving the same command order as the script.
- Run `node --check libs.mjs` after changing the script.
- Use `node ./libs.mjs delete --dry-run` when testing deletion behavior. Never run the real deletion command unless the user explicitly requests the deletion itself.
