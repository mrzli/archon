# Archon CLI development and deployment

Archon CLI lives at `components/archon-cli`. Source and tests use Ruby's
standard library, with no gem dependencies or build step.

## Runtime and installation

The directly runnable source tree is:

```text
components/archon-cli/
├── bin/
│   ├── archon          # Ruby launcher, #!/usr/bin/env ruby
│   └── arc -> archon   # relative symlink
└── lib/archon/         # Ruby modules
```

Only the launcher has a runtime shebang. It loads `../lib/archon/cli.rb`.
Modules do not execute commands when required. The same relative paths work
in the repository and after installation.

`setup.sh` delegates to the Ruby setup code. CLI installation copies `bin/`
into `~/.local/bin/` and `lib/` into `~/.local/lib/` using `rsync -a`, excluding
Markdown from the library copy. Tests and contributor documentation are not
installed. The installed commands need Ruby on `PATH` and the external tools
used by their operations. They do not depend on the source checkout.

Bun remains an external tool for `archon libs build` and the configured
frontend workspace command. CLI installation and tests do not require Bun.

Installation updates managed CLI files and preserves unrelated destination
files. Repeated installation converges without generating artifacts. Setup
contains no one-time cleanup of files from previous installations. Old
JavaScript modules in an existing home directory are not loaded by Ruby and
are not deleted by the overlay.

## Verification

```bash
bash tests/test.sh
```

This runs setup, skill-link, video-workaround, WoW setup, and CLI checks.
Use `ruby tests/profile.rb` to run the same checks and print per-file and total
times. Runner totals include their child tests; do not add those rows together.
Terminal tests create their own pseudo terminals; the command also works with
stdin redirected from `/dev/null`. The optional Codex timing stress check is
run separately, as described in the [test instructions](../components/archon-cli/tests/README.md).

For CLI checks alone, run `bash components/archon-cli/tests/run.sh`.
The CLI runner executes each Ruby test file in a separate process, checks Ruby
syntax, exercises the Bash workspace
adapter, and verifies installation. Installation tests call the production
CLI copy function with a temporary home, check both executable aliases,
exclude development files, and verify repeated copies preserve unrelated files.
Bash syntax and available ShellCheck checks follow.

Tests use isolated homes, local Git fixtures, and fake external commands.
Terminal attachment checks use pseudo terminals. Shutdown tests use a separate
temporary tmux socket to verify that stopping workspaces survives closing the
calling pane. Herdr checks simulate the installed CLI response shapes with a
fake executable and temporary state, including server startup and detached
shutdown. The tests
do not run full workstation setup or touch live tmux or Herdr sessions or home
configuration.
