# Archon CLI tests

Run the component suite from the repository root:

```bash
components/archon-cli/test.sh
```

The repository-level `tests/archon-cli/run.sh` command adds installation,
migration, shell syntax, ShellCheck, and whitespace checks.

Test behavior at the lowest layer that fully protects the contract:

- `*-cli.test.mjs` covers command wiring, output, and external command
  construction with temporary homes and fake executables.
- Focused module tests cover validation, ordering, and workflow policy
  directly. Do not repeat those cases through the CLI unless the command
  boundary adds behavior.
- `*-missing-root.test.mjs` keeps the empty-state regression matrix explicit.
- `repository-status.test.mjs` exercises the shared inspection behavior with
  temporary real Git repositories.
- Workspace module tests live under `tests/workspaces`.
- Repository-level shell tests cover installation and migration behavior plus
  the fake-tmux end-to-end adapter check.

Tests must not use the real home directory, GitHub account, or tmux server.

## Complete verification

```bash
bash tests/archon-cli/run.sh
bash tests/archon-cli/run.sh < /dev/null
```

Both invocations must pass. The complete runner includes the component suite,
workspace adapter, installation-layout and migration checks, individual
Bash syntax checks, and whitespace validation. ShellCheck runs when installed
and is explicitly reported as unavailable otherwise.

The suite requires Bash, Node.js, Git, rsync, standard Arch command-line tools,
and the util-linux `script` utility. Terminal tests use coreutils `timeout` to
bound each pseudo-terminal command to 15 seconds. A missing terminal-test
prerequisite fails the adapter explicitly.

## Workspace fixtures

Each adapter case owns a temporary home, project roots, fake tmux state, and
command log, cleaned up by its subshell's exit trap. Non-interactive CLI calls
read stdin from `/dev/null`; terminal cases run the actual CLI through `script`
with fake tmux on PATH. The fake validates existing attachment targets, including
exact `=name` targets, and records attachments without opening a tmux client.
Keep module tests for failure and routing policy; use terminal integration
tests for actual environment and stdin wiring.

## Git fixtures

Use `createGitEnvironment` for child processes and the synchronous
`withGitFixture` scope for in-process real-Git workflows. `runArchon` applies
the same environment automatically. These helpers strip inherited `GIT_*`
settings, use a temporary home/config location, disable global/system Git
configuration, hooks, and commit signing, and provide a test identity.
Pass intentional per-test environment overrides explicitly.

`withGitFixture` restores the original process environment and removes its
fixture in `finally`. Its callback must be synchronous; do not run concurrent
tests that change process environment within the same test process. Real Git
repositories and remotes must remain local to temporary fixtures.

## Installation fixtures

Layout tests reproduce the CLI copy operations in temporary homes and check
runtime imports, the shortcut, filtering, and repeated installation. Their
replacement case simulates removal of the managed library directory; it does
not execute or verify setup's removal implementation. Keep that limitation
explicit when interpreting these checks. Production home-installation commands
remain in `setup.sh`; never run complete workstation setup as a test.
