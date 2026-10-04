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
and nonterminal behavior. Real tmux integration tests run separately; the
default suite does not require Unix socket access. ShellCheck runs when
installed and is reported as unavailable otherwise. No build or dependency
installation is required.

Run all Archon checks, including setup and WoW setup, from the repository root:

```bash
bash tests/test.sh
```

Run the same checks with a timing summary:

```bash
ruby tests/profile.rb
```

The complete suite also requires Lua, Python 3, and unzip.

The suite requires Ruby, Bash, Git, rsync, standard Arch command-line tools,
the util-linux `script` and `setsid` utilities, and coreutils `timeout`.

Herdr checks use a fake executable and temporary state. They do not require
Herdr or start real editors, agents, or development servers.

Run real tmux integration tests when changing workspace shutdown or Codex
restart behavior, and before releases:

```bash
bash components/archon-cli/tests/run-integration.sh
```

These checks require tmux at `/usr/bin/tmux` and permission to create Unix
sockets. They use isolated temporary servers and fake Codex processes, and
preserve live sessions. The default suite and timing command exclude them.

Run the optional twelve-pane Codex restart stress check separately:

```bash
ruby components/archon-cli/tests/stress/codex_test.rb
```

This timing check uses fake Codex processes in an isolated tmux server. Run it
when changing restart performance, on a machine without heavy background load.
It is excluded from the regular suite.
