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
into `~/.local/bin/` using `rsync -a`, and mirrors `lib/archon/` into
`~/.local/lib/archon/` using `rsync -a --delete`, excluding Markdown.
Home-file installation does not touch the CLI directories, so a setup step that
fails before CLI installation leaves the previous CLI working. Tests and contributor documentation are not
installed. The installed commands need Ruby on `PATH` and the external tools
used by their operations. They do not depend on the source checkout.

Bun remains an external tool for `archon projects libs build`. CLI installation and
tests do not require Bun.

Installation removes files under `~/.local/lib/archon` that are no longer in
the source and preserves unrelated files in `~/.local/bin` and `~/.local/lib`.
Repeated installation converges without generating artifacts.

## Verification

```bash
bash tests/test.sh
```

This runs setup, skill-link, video-workaround, WoW setup, and CLI checks.
Use ordinary test commands for routine verification. Run `ruby tests/profile.rb`
only when the user explicitly requests test profiling. It runs the same checks
and prints per-file and total times. Runner totals include their child tests;
do not add those rows together.
Terminal tests create their own pseudo terminals; the command also works with
stdin redirected from `/dev/null`. Real tmux integration tests and the optional
Codex timing stress check run separately, as described in the
[test instructions](../components/archon-cli/tests/README.md).

For CLI checks alone, run `bash components/archon-cli/tests/run.sh`.
The CLI runner executes each default Ruby test file in a separate process,
checks Ruby syntax and verifies installation. Installation tests call the
production CLI copy function with a temporary home, check both executable aliases,
exclude development files, and verify repeated copies preserve unrelated files.
Bash syntax and available ShellCheck checks follow.

Tests use isolated homes, local Git fixtures, and fake external commands.
Terminal attachment checks use pseudo terminals. Default Herdr checks simulate the
installed CLI response shapes with a fake executable and temporary state,
including server startup and detached shutdown. The tests
do not run full workstation setup or touch live tmux or Herdr sessions or home
configuration.

Run `bash components/archon-cli/tests/run-integration.sh` when changing workspace
shutdown or Claude or Codex restart behavior, and before releases. These separate tests
use isolated Herdr sessions and temporary tmux sockets to verify that kill
clears saved layouts, stopping workspaces survives closing the calling pane,
and Claude and Codex restarts preserve real shells and panes. They require Unix socket
access; the default suite and timing command do not.
