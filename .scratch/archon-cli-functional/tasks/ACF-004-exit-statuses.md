# ACF-004: Standardize usage-error exit statuses

Status: completed

Completed: 2026-09-05

Area: Command interface

Depends on: ACF-003

Source: [Archon CLI functional improvement tasks](../tasks.md)

## Outcome

Apply one public exit-status convention across the root dispatcher and the
projects, libraries, and workspaces command collections.

## Acceptance checklist

- [x] Add or update integration tests for help, usage errors, and operational
      failures at every command layer.
- [x] Return `0` when a command completes successfully.
- [x] Return `0` for root, projects, libraries, workspaces, and
      command-specific help requests.
- [x] Return `2` for missing required commands or actions, unknown commands,
      unexpected operands, and invalid or unsupported options.
- [x] Return `1` for representative Git, GitHub, Bun, tmux, filesystem,
      validation, and partial-operation failures.
- [x] Change existing projects and libraries usage failures from `1` to `2`.
- [x] Ensure lower-level command helpers return ordinary status results and do
      not terminate the process themselves.
- [x] Preserve existing signal-termination behavior; if implementation work
      must change it, document the chosen contract and add focused tests.
- [x] Preserve standard-output and standard-error routing except where a
      corrected usage status requires test expectation updates.
- [x] Preserve continued processing of independent repositories, sessions, and
      groups after individual operational failures.
- [x] Run the complete canonical CLI suite at this checkpoint.

## Verification

- Exercise the installed `archon` entry point and direct module harnesses with
  valid commands, help requests, invalid invocations, and injected operational
  failures.
- Run `tests/archon-cli/run.sh`.
- Run Node syntax checks for every changed executable and `.mjs` file.
- Run `git diff --check`.

Completed with an installed-entry-point matrix covering every projects and
libraries command, domain-level missing and unknown commands, help requests,
and existing root/workspace syntax handling. A tmux child terminated by a
signal now maps to operational status `1`; Archon does not signal itself, so it
can report the failure and continue independent work. The canonical suite
passed all 112 Node tests and 13 shell-suite checks, plus Node and Bash syntax
checks and `git diff --check`. ShellCheck was unavailable and reported as
skipped.
