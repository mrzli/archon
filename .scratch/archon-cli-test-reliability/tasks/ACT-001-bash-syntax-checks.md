# ACT-001: Check every Bash script

Status: completed

Area: Verification runner

Depends on: none

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Outcome

Make the canonical runner validate every intended Bash script and fail on any syntax error.

## Expected files

`tests/archon-cli/run.sh` and focused verification fixtures as needed.

## Acceptance checklist

- [x] Replace the multi-file Bash invocation with one quoted `bash -n` invocation per path.
- [x] Include relevant new scripts as later tasks introduce them; preserve separate optional ShellCheck execution.
- [x] Verify a syntax error after the first file makes the check fail, using temporary fixtures or an isolated copy.
- [x] Verify valid scripts and a filename containing spaces pass.
- [x] Leave no intentionally invalid files in the working tree.

## Verification

- Exercise the production syntax-check loop with valid and invalid temporary inputs.
- Run the canonical suite non-interactively; the known interactive adapter failure is addressed by ACT-002 and ACT-003.
- Run `git diff --check`.

Completed: 2026-09-06. The production loop accepted valid paths (including
spaces) and rejected a later invalid script in temporary fixtures. The canonical
non-interactive suite passed. ShellCheck was unavailable.
