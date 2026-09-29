# Archon CLI Instructions

## Scope

- Develop source and tests in Ruby using only the standard library.
- Run and install source directly. Do not add compilation, generated runtime
  artifacts, or package dependencies.
- Keep fixed workstation paths derived from the current user's home directory.

## Code conventions

- Use modules, plain functions, and hashes rather than classes.
- Give command entry functions distinct, descriptive names and explicit
  arguments or context parameters.
- Use `require_relative` for local modules. Imported modules must not execute
  commands as an import side effect.
- Bind production dependencies at command boundaries. Injected replacements
  must not silently fall back to real external operations.
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
- When a command has substantial subcommands, give each its own headed section
  in the command's README, with its prerequisites, examples, and behavior.
- Do not document internal functioning, architecture, source layout, or test
  implementation in READMEs. Keep general contributor rules in AGENTS.md and
  task-specific design decisions in the relevant planning records.

## Verification

- Run the component suite and complete installation integration checks for
  runtime changes.
- Update the relevant README whenever command usage or behavior changes.
- Check Ruby syntax with `ruby -c` without executing modules. Run behavioral
  checks against the executable and an isolated installation.
- Use temporary roots and fake external commands for destructive or
  workstation-mutating behavior.
- Run `git diff --check`.
