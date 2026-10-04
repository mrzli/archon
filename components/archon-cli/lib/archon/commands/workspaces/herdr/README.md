# Herdr workspaces command

Requires Herdr on `PATH`, plus Neovim, the selected AI tool, Bun, and pnpm for the configured
project commands. Manage workspaces in a dedicated Herdr session named `archon`:

```bash
archon workspaces herdr start
arc w h start -g flashcards
arc w h start --group flashcards --ai claude
arc w h stop --group jslibs
arc w h stop
arc w h kill
```

For `start`, use `--ai codex` (the default) or `--ai claude` to choose the AI
tab. Codex runs `codex resume --last`; Claude Code runs `claude --continue`.
The option applies only to newly created workspaces. Stop and start a group to
change its AI tool. The `general` group has only a shell and is unaffected.

The groups match `archon workspaces tmux`:

- `general`: a `main` workspace with a shell at `~/projects`.
- `flashcards`: frontend and backend workspaces, each with Neovim, the selected AI tool,
  development, and shell tabs.
- `jslibs`: immediate non-hidden repositories under
  `~/projects/personal/mrzli-jslib`, with Neovim, the selected AI tool, and shell tabs.
- `misc`: the configured personal projects, with Neovim, the selected AI tool,
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
