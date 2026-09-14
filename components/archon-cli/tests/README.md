# Archon CLI tests

Run the component suite from the repository root:

```bash
bash components/archon-cli/test.sh
```

Run complete verification with terminal stdin, then without it:

```bash
bash tests/archon-cli/run.sh
bash tests/archon-cli/run.sh < /dev/null
```

Both invocations must pass. Complete verification checks behavior, installation,
syntax, and whitespace. ShellCheck runs when installed and is reported as
unavailable otherwise. No build or dependency installation is required.

The suite requires Ruby, Bash, Git, rsync, standard Arch command-line tools,
the util-linux `script` and `setsid` utilities, tmux, and coreutils `timeout`.
Shutdown regression tests use a separate temporary tmux socket and require
permission to create Unix sockets.
