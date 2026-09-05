# Archon CLI test reliability

Status: completed and archived

Completed: 2026-09-06

Implementation plan: [Task index](./tasks.md)

Created: 2026-09-06

## Context

The CLI test review identified four improvements to the verification suite:

1. `tests/archon-cli/test-workspaces-adapter.sh` assumes startup never attaches
   to tmux. The CLI now intentionally attaches after successful interactive
   startup outside tmux. The adapter passed without a terminal but failed in a
   terminal with `aggregate start unexpectedly attached or switched clients`.
2. `tests/archon-cli/run.sh` passes multiple filenames to `bash -n`. Bash parses
   only the first script; the remaining filenames become script arguments.
3. `tests/archon-cli/test-install-layout.sh` duplicates installation commands
   and removes a stale library directory itself. It can therefore pass when
   the corresponding production installation behavior is broken.
4. Real Git tests inherit personal configuration and environment variables.
   Fixture commits and updates can be affected by signing settings, hooks,
   repository overrides, and configuration outside the temporary fixture.

The non-interactive suite passed during review. The terminal failure and Bash
syntax-check issue were reproduced. Installation drift and Git environment
dependence are gaps identified by inspection, not observed production failures.
ShellCheck was unavailable during that verification.

## Goals and scope

- Make verification produce consistent results with and without a terminal.
- Check the syntax of every intended Bash script.
- Exercise the installation operations used by setup against temporary paths.
- Isolate real Git fixture operations and code under test from personal state.
- Preserve the existing split between focused module tests and CLI integration
  tests, and retain `tests/archon-cli/run.sh` as the complete suite entry point.

This work does not change CLI commands, aliases, workspace behavior, or Git
workflow policy. It does not add a general testing framework, npm dependencies,
or broad provisioning refactors. One-time migrations and legacy cleanup remain
outside `setup.sh`.

## 1. Explicit terminal behavior in workspace tests

Keep fake tmux and temporary project roots for all workspace tests. Never
connect to the user's tmux server or launch real editors or development tools.

Each adapter case must own fresh fixture state and command logs. Assertions
must describe only calls made by that case, including its startup and shutdown.

Run non-interactive CLI cases with stdin explicitly redirected from
`/dev/null`, independent of how the test runner was launched. Add a focused
integration case that runs the actual CLI through a pseudo-terminal, using
the existing fake tmux executable. A platform-provided PTY utility is suitable;
report a missing prerequisite explicitly rather than silently omitting the
check. Bound the terminal subprocess so an attachment regression cannot hang
the suite indefinitely.

Retain focused module coverage for routing and failure policy. Integration
coverage should verify the real environment and stdin wiring rather than
duplicate every module case.

### Acceptance cases

- The adapter passes both from an interactive terminal and with redirected
  stdin.
- Non-interactive startup creates the requested workspace sessions and does
  not attach or switch clients.
- Interactive aggregate startup outside tmux attaches exactly once to `main`.
- Interactive named-group startup attaches to a session from that group.
- Interactive startup with `TMUX` set does not attach or switch clients.
- Stop and help do not attach; failed startup does not attach.
- Attachment creates no additional session. The fake records the exact target
  and validates that the target exists, including the `=name` target syntax.
- Cases can run independently without stale sessions or log entries affecting
  their results.

## 2. Complete Bash syntax checks

Run `bash -n` separately for each path in the runner's syntax-check list.
Preserve quoted paths and propagate a syntax error as a nonzero suite result.
Include any new installation or verification scripts introduced by this work.
Keep the existing separate ShellCheck step when the tool is available.

### Acceptance cases

- Every listed file receives an individual Bash syntax check.
- An invalid script after the first entry causes verification to fail. Verify
  this with a temporary test fixture or isolated copy, never by leaving a
  syntax error in the working tree.
- Valid scripts, including a path containing spaces, pass.

## 3. Shared installation operations

Extract the smallest production installation boundary needed for the CLI
layout tests. Setup and tests must invoke the same implementation for the
operations they claim to verify. Pass explicit source and destination paths
so tests can use temporary homes without running the complete setup script.

The boundary must cover both copying the CLI runtime and replacing its managed
library directory. Account for setup's existing managed-directory replacement
phase: extracting only the copy commands while tests continue to delete stale
files themselves does not close the coverage gap. Avoid introducing a second
replacement policy or expanding into unrelated provisioning logic.

The installed layout remains:

- `~/.local/bin/archon`: executable entry point.
- `~/.local/bin/arc -> archon`: relative shortcut.
- `~/.local/lib/archon/`: managed runtime modules.

Development instructions, documentation, and tests remain excluded from the
runtime installation. Preserve unrelated home files and sibling libraries.
Do not add removal of the former `a` shortcut or other legacy migration steps.

### Acceptance cases

- A first installation succeeds in a temporary home.
- A second installation succeeds and converges on the same intended layout.
- Seed a stale module before installation; the production replacement operation
  removes it without the test deleting it first.
- Unrelated sibling files survive replacement.
- The entry point remains executable, runtime imports resolve, and `arc`
  produces the same help output as `archon`.
- No development-only files are installed.
- Existing overlay-only checks remain distinct from full managed-directory
  replacement checks; preservation inside the overlay is not mistaken for
  preservation inside a replacement directory.
- Tests never run full workstation setup or install into the real home.

## 4. Controlled Git environment

Use a small shared test helper to construct the environment for real Git
operations. Apply it consistently to fixture initialization and to subprocesses
and in-process workflows under test that invoke Git.

The environment must use temporary configuration locations, disable system
and global Git configuration, prevent hooks and signing from affecting fixture
commands, and remove inherited Git repository/configuration overrides. Set
fixture identity explicitly. Preserve only intentionally supplied test Git
settings. Keep required executable lookup available without changing real
user configuration.

For in-process tests, either run the test process under this environment or
scope and restore environment changes reliably. Do not add production CLI
options solely to support test isolation.

### Acceptance cases

- Repository-status and synchronization tests pass with local temporary Git
  repositories and no network or personal credentials.
- Synthetic external settings requesting commit signing or defining a failing
  hook cannot affect fixture commits. The sentinel hook is never executed.
- Synthetic inherited repository overrides cannot redirect a fixture command
  to a different repository.
- Temporary identity and configuration apply to both fixture preparation and
  the Git commands executed by the code under test.
- Environment changes are restored and fixtures are cleaned up after failures.

## Implementation sequence

1. Correct the Bash syntax loop and verify failure on a later invalid file.
2. Make adapter fixtures independent, then add explicit terminal and
   non-terminal integration coverage.
3. Extract and test the shared installation operations with repeat-install,
   stale-module, and preservation cases.
4. Isolate Git operations and verify with synthetic conflicting configuration.
5. Run complete verification and update durable test documentation.

## Verification and completion

- Run `components/archon-cli/test.sh` through the complete
  `tests/archon-cli/run.sh` entry point.
- Verify the complete runner with and without a terminal.
- Run `node --check` for changed executables and modules, individual `bash -n`
  checks for changed shell scripts, and ShellCheck when available.
- Run `git diff --check`; also check staged changes when implementation changes
  have been staged.
- Do not execute the complete `setup.sh` as a test.
- Update `components/archon-cli/tests/README.md` with test isolation rules and
  terminal-test prerequisites. Document the installation boundary where it is
  maintained.
- Record verification results and any unavailable checks, then mark this
  specification completed and archived. Enduring operational guidance belongs
  in the relevant README or `docs/`, not only in this proposal.

## Completion record

All six tasks were implemented in separate commits. The complete suite passed
with terminal and non-terminal stdin. Focused verification rejected a later
invalid Bash file, confirmed valid paths containing spaces, validated attachment
targets without real tmux, and exercised production replacement and isolated
Git workflows under synthetic conflicting settings. Node and individual Bash
syntax checks and whitespace checks passed. ShellCheck was unavailable.

The installation extraction preserves the existing default overlay and optional
managed-directory replacement modes. Full workstation setup was not executed.
Maintained guidance is in the root README and `components/archon-cli/tests/README.md`.
