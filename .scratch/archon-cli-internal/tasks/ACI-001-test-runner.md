# ACI-001: Add the canonical CLI verification runner

Status: pending

Area: Test infrastructure

Depends on: none

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Provide one documented, safe command that executes the complete focused Archon
CLI verification suite.

## Acceptance checklist

- [ ] Add executable `tests/archon-cli/run.sh`.
- [ ] Run all Archon CLI Node tests in deterministic groups.
- [ ] Run root/domain, workspace adapter, installation-layout, and migration
      shell suites.
- [ ] Check every Archon CLI executable and `.mjs` file with `node --check`.
- [ ] Check relevant Bash scripts with `bash -n`.
- [ ] Run ShellCheck when available and report a concise skip when absent.
- [ ] Run `git diff --check`.
- [ ] Stop and return nonzero when any required check fails.
- [ ] Do not run `setup.sh` or contact real GitHub, tmux, editors, Codex, or
      development servers.
- [ ] Document the runner in the relevant Archon CLI contributor instructions.
- [ ] Preserve all production CLI behavior.

## Verification

- Run `bash -n tests/archon-cli/run.sh`.
- Run ShellCheck on the runner when available.
- Run `tests/archon-cli/run.sh`.
- Confirm its output identifies each suite or check clearly.
- Run `git diff --check`.
