# Herdr workspaces command

Requires Herdr on `PATH`, plus Neovim, Codex, Bun, and pnpm for the configured
project commands. Manage workspaces in a dedicated Herdr session named `archon`:

```bash
archon workspaces-herdr start
arc wh start -g flashcards
arc wh stop --group jslibs
arc wh stop
arc wh kill
```

The groups match `archon workspaces`:

- `general`: a `main` workspace with a shell at `~/projects`.
- `flashcards`: frontend and backend workspaces, each with Neovim, Codex,
  development, and shell tabs.
- `jslibs`: immediate non-hidden repositories under
  `~/projects/personal/mrzli-jslib`, with Neovim, Codex, and shell tabs.
- `misc-projects`: the configured personal projects, with Neovim, Codex,
  and shell tabs.

Start runs groups in the order above; stop uses the reverse order. Missing
project directories are reported and skipped. Repeated starts preserve existing
workspaces and tabs. Failed creations roll back the new workspace and report
cleanup failures; later workspaces are still attempted.

Start launches the session's background server when needed. An interactive
start outside Herdr focuses the requested group and attaches to `archon`.
Aggregate start prefers `main`. Inside Herdr, start preserves your current
view. Non-interactive starts do not attach. Attach manually with:

```bash
herdr --session archon
```

Stop closes only the selected managed workspaces, preserving unrelated ones.
When the last workspace belongs to the selected group, stop shuts down the
`archon` session directly so Herdr does not create a replacement workspace.
This also applies when stopping all groups. Herdr retains the last workspace's
saved layout; its processes stop.
It does not delete project directories or Git worktrees. Stop from a Herdr pane
runs independently so closing that pane does not interrupt the remaining work.

`kill` takes no arguments. It stops the entire `archon` session, including any
extra workspaces you added there, and leaves Herdr's saved session data intact.
Other Herdr sessions and tmux sessions are unaffected. Stop and kill succeed
when the target session is already stopped.

Server startup diagnostics and detached shutdown output are saved in
`${XDG_STATE_HOME:-$HOME/.local/state}/archon/workspaces-herdr-server.log` and
`workspaces-herdr-stop.log`, respectively.
