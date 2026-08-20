#!/usr/bin/env bash

create_session() {
  local session="$1"
  local dir="$2"

  [ -d "$dir" ] || return

  if ! tmux has-session -t "$session" 2>/dev/null; then
    tmux new-session -d -s "$session" -c "$dir" -n shell
  fi
}

create_session workspaces "$HOME/projects/workspaces"
create_session projects "$HOME/projects/personal"
create_session libs "$HOME/projects/personal/mrzli-jslib"
