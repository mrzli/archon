# Project conventions

Archon provisions and maintains the desired state of an Omarchy/Arch Linux
workstation. Target Ruby, Bash, and the current Omarchy environment. Do not
add cross-platform abstractions.

- `setup.sh` bootstraps Ruby and runs the setup in `setup/`, the main
  provisioning entry point. [The installation guide](docs/installation.md) is
  the user's procedure for installing a new machine.
- `data/home/` mirrors files that setup copies into the user's home directory
  ([AGENTS.md](data/AGENTS.md)).
- `components/archon-cli/` is the `archon` command-line program
  ([AGENTS.md](components/archon-cli/AGENTS.md)). Read
  [its development guide](docs/archon-cli-development.md) before changing it.
- `migrations/` holds one-time scripts for superseded configurations, which
  setup does not run.

Read a directory's `AGENTS.md` before working in it.

Before planning a change, search `docs/` and `.scratch/` for related context.
Include hidden paths so the search does not skip `.scratch/`. `docs/`
describes the current behavior. `.scratch/` may describe work that is not
implemented yet, so check the code before treating it as current. Update
`docs/` only when asked or when a change makes it inaccurate. Keep README
files to user instructions, not implementation details.

# Changing the workstation

When asked to change the workstation, such as adding or editing a
configuration file or installing software, make the change in this
repository: add or edit a file under `data/home/`, or add a step to setup.
The user applies it by running `setup.sh`. Change the live system only when
the user asks.

`data/home/` is an overlay, not a replacement of the home directory. Files
there overwrite their destinations, and other home files must stay untouched.
Preserve the directory structure, prefer declarative configuration files over
setup logic, and say when a new managed file may replace an existing user
file. Never add secrets, machine-specific credentials, or private keys.

When installing software, choose the first method that applies:

1. `omarchy install <group> <app>` when Omarchy provides an installer, because
   it also handles configuration, drivers, or runtime setup.
2. `omarchy install dev-env <language>` for language runtimes Omarchy
   supports.
3. `omarchy pkg add` for packages in the official or Omarchy repositories.
4. `mise use --global` for developer command-line tools that should track
   upstream releases, or whose repository package would pull in a large
   dependency tree.
5. `omarchy pkg aur add` only when no earlier method provides the software.

Do not install with `pacman` or `yay` directly. The Omarchy wrappers skip
installed packages and verify the result.

# Setup invariants

Setup provisions the current desired state only. Put one-time migration or
cleanup of superseded configurations, names, or paths in `migrations/` or in
explicit manual commands.

Setup must be convergent and repeat-safe. Running it again on a configured
machine must succeed without manual cleanup, converge on the same
configuration, avoid duplicate lines, entries, packages, or resources,
tolerate resources that are already present or absent, and preserve user data
outside managed paths. Updated versions, refreshed caches and metadata,
reloaded services, and regenerated equivalent output are fine, as long as they
cause no drift or duplicate state.

When adding a setup step:

- Prefer naturally idempotent package-manager and configuration commands.
  Otherwise inspect the current state before changing it.
- Make appends conditional.
- Give destructive operations narrow, explicit targets, and let them succeed
  when the target is already absent.
- Do not generate new credentials, keys, tokens, or other identities on every
  run.
- Get the user's approval before adding a step that is intentionally not
  repeatable, and document it.

# Required checks

Choose the checks by the kind of change:

- **Documentation only:** `git diff --check`.
- **Configuration under `data/home/`:** the file's own syntax or configuration
  validation, without installing it into the real home directory, and
  `git diff --check`.
- **Code,** including setup, components, tests, migrations, and shell scripts
  under `data/home/`: `bash tests/test.sh`, which also runs the syntax checks
  and ShellCheck.

Never run `setup.sh` or full provisioning as a test, because it changes the
workstation. Verify single setup operations with focused, safe checks.
