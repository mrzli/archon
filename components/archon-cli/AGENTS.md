# Archon CLI Instructions

## Scope

- Develop source, tests, and build tooling in strict TypeScript. Use Bun with
  ECMAScript modules and no third-party runtime packages.
- Deploy emitted JavaScript only. Keep the executable launcher in JavaScript;
  only the launcher needs a runtime shebang.
- Development-only tooling dependencies are permitted; keep them out of the
  installed runtime artifact.
- Preserve the configured minimum package release age; do not add exemptions
  or bypass it when resolving dependencies.
- Keep fixed workstation paths derived from the current user's home directory.

## Code conventions

- Give command entry functions distinct, descriptive names and explicit
  arguments/context parameters. Avoid renaming generic exports at import sites.
- Each command barrel exports only its entry function. Other barrels re-export
  their modules with `export *`.
- Use barrels across runtime module boundaries. Imports within the same
  directory must reference sibling modules directly, never their barrel.
  Focused tests may import internal modules directly.
- Keep executable behavior at the executable boundary; imported modules must
  not execute commands as an import side effect.
- Use plain objects and functions rather than classes. Bind production
  dependencies at command boundaries; injected replacements must not silently
  fall back to real external operations.
- Wrap every `switch` case body, including `default`, in braces.
- Keep named commands alphabetical in routing, help, and documentation.
- Run subprocesses with argument arrays and no shell unless intentionally
  sending a command string to another program.
- Keep terminal output concise and send usage errors to standard error.

## Documentation

- Keep all AGENTS.md files focused on general patterns and reusable rules.
  Do not record implementation inventories, module ownership, named helper
  prescriptions, or descriptions of how particular features currently work.
  A concrete example is optional and must illustrate a general rule rather
  than prescribe a specific implementation.
- Keep every README usage-only: commands, options, examples, prerequisites,
  and user-visible behavior. Test READMEs document how to run tests and their
  prerequisites.
- Do not document internal functioning, architecture, source layout, or test
  implementation in READMEs. Keep general contributor rules in AGENTS.md and
  task-specific design decisions in the relevant planning records.

## Verification

- Run the component suite and complete installation integration checks for
  runtime changes.
- Run strict type checking for TypeScript changes, including converted tests.
- Update the relevant README whenever command usage or behavior changes.
- Parse changed JavaScript executables and modules with Bun without executing
  them; run behavioral checks against the built artifact.
- Use temporary roots and fake external commands for destructive or
  workstation-mutating behavior.
- Run `git diff --check`.
