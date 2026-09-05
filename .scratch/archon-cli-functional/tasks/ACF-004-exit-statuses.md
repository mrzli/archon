# ACF-004: Standardize usage-error exit statuses

Status: pending

Area: Command interface

Depends on: ACF-003

Source: [Archon CLI functional improvement tasks](../tasks.md)

## Outcome

Apply one public exit-status convention across the root dispatcher and the
projects, libraries, and workspaces command collections.

## Acceptance checklist

- [ ] Add or update integration tests for help, usage errors, and operational
      failures at every command layer.
- [ ] Return `0` when a command completes successfully.
- [ ] Return `0` for root, projects, libraries, workspaces, and
      command-specific help requests.
- [ ] Return `2` for missing required commands or actions, unknown commands,
      unexpected operands, and invalid or unsupported options.
- [ ] Return `1` for representative Git, GitHub, Bun, tmux, filesystem,
      validation, and partial-operation failures.
- [ ] Change existing projects and libraries usage failures from `1` to `2`.
- [ ] Ensure lower-level command helpers return ordinary status results and do
      not terminate the process themselves.
- [ ] Preserve existing signal-termination behavior; if implementation work
      must change it, document the chosen contract and add focused tests.
- [ ] Preserve standard-output and standard-error routing except where a
      corrected usage status requires test expectation updates.
- [ ] Preserve continued processing of independent repositories, sessions, and
      groups after individual operational failures.
- [ ] Run the complete canonical CLI suite at this checkpoint.

## Verification

- Exercise the installed `archon` entry point and direct module harnesses with
  valid commands, help requests, invalid invocations, and injected operational
  failures.
- Run `tests/archon-cli/run.sh`.
- Run Node syntax checks for every changed executable and `.mjs` file.
- Run `git diff --check`.
