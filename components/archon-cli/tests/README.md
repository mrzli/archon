# Archon CLI tests

Run the component suite from the repository root:

```bash
NODE_ENV=development bun install --frozen-lockfile --cwd components/archon-cli
bun run --cwd components/archon-cli test
```

This typechecks and builds the CLI before running component and workspace
integration tests.
Alternatively, run `components/archon-cli/test.sh` directly.

Run complete verification with terminal stdin, then without it:

```bash
bash tests/archon-cli/run.sh
bash tests/archon-cli/run.sh < /dev/null
```

Both invocations must pass. Complete verification also checks installation,
syntax, and whitespace. ShellCheck runs when installed and is
reported as unavailable otherwise.

The suite requires Bash, Bun, Git, rsync, standard Arch command-line tools,
the util-linux `script` and `setsid` utilities, tmux, and coreutils `timeout`.
Shutdown regression tests use a separate temporary tmux socket and require
permission to create Unix sockets.
