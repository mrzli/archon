# Archon CLI tests

Run the component suite from the repository root:

```bash
components/archon-cli/test.sh
```

Run complete verification with terminal stdin, then without it:

```bash
bash tests/archon-cli/run.sh
bash tests/archon-cli/run.sh < /dev/null
```

Both invocations must pass. Complete verification also checks installation,
migration, syntax, and whitespace. ShellCheck runs when installed and is
reported as unavailable otherwise.

The suite requires Bash, Node.js, Git, rsync, standard Arch command-line tools,
the util-linux `script` utility, and coreutils `timeout`.
