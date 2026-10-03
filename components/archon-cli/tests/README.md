# Archon CLI tests

Run the component suite from the repository root:

```bash
bash components/archon-cli/test.sh
```

Run CLI verification, including installation:

```bash
bash components/archon-cli/tests/run.sh
```

CLI verification checks behavior, installation, syntax, and whitespace.
Terminal tests create their own pseudo terminals, so one run covers terminal
and nonterminal behavior. ShellCheck runs when installed and is reported as
unavailable otherwise. No build or dependency installation is required.

Run all Archon checks, including setup and WoW setup, from the repository root:

```bash
bash test.sh
```

The complete suite also requires Lua, Python 3, and unzip.

The suite requires Ruby, Bash, Git, rsync, standard Arch command-line tools,
the util-linux `script` and `setsid` utilities, tmux, and coreutils `timeout`.
Shutdown regression tests use a separate temporary tmux socket and require
permission to create Unix sockets.

Herdr checks use a fake executable and temporary state. They do not require
Herdr or start real editors, agents, or development servers.

Run the optional twelve-pane Codex restart stress check separately:

```bash
ruby components/archon-cli/tests/stress/codex_test.rb
```

This timing check uses fake Codex processes in an isolated tmux server. Run it
when changing restart performance, on a machine without heavy background load.
It is excluded from the regular suite.
