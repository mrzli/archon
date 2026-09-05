# ACI-001: Add the canonical CLI verification runner

Status: completed

Completed: 2026-09-05

Area: Test infrastructure

Depends on: none

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Provide one documented, safe command that executes the complete focused Archon
CLI verification suite.

## Acceptance checklist

- [x] Add executable `tests/archon-cli/run.sh`.
- [x] Run all Archon CLI Node tests in deterministic groups.
- [x] Run root/domain, workspace adapter, installation-layout, and migration
      shell suites.
- [x] Check every Archon CLI executable and `.mjs` file with `node --check`.
- [x] Check relevant Bash scripts with `bash -n`.
- [x] Run ShellCheck when available and report a concise skip when absent.
- [x] Run `git diff --check`.
- [x] Stop and return nonzero when any required check fails.
- [x] Do not run `setup.sh` or contact real GitHub, tmux, editors, Codex, or
      development servers.
- [x] Document the runner in the relevant Archon CLI contributor instructions.
- [x] Preserve all production CLI behavior.

## Verification

- Run `bash -n tests/archon-cli/run.sh`.
- Run ShellCheck on the runner when available.
- Run `tests/archon-cli/run.sh`.
- Confirm its output identifies each suite or check clearly.
- Run `git diff --check`.

Completed with all 29 Node tests and all 15 shell-suite checks passing. Node
and Bash syntax checks and `git diff --check` passed. ShellCheck was unavailable
and was reported as skipped. The first sandboxed run correctly stopped on an
`EPERM` restriction for nested Git processes; the complete isolated suite
passed when rerun with subprocess access.
