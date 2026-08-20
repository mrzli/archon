#!/usr/bin/env bash

ROOT="$HOME/projects/personal/mrzli-jslib"

[ -d "$ROOT" ] || exit 0

create_session() {
  local session="$1"
  local dir="$2"

  if tmux has-session -t "$session" 2>/dev/null; then
    return
  fi

  tmux new-session -d -s "$session" -c "$dir" -n nvim
  tmux send-keys -t "$session:nvim" 'nvim .' Enter

  tmux new-window -t "$session" -c "$dir" -n codex
  tmux send-keys -t "$session:codex" 'codex resume --last' Enter

  tmux new-window -t "$session" -c "$dir" -n shell

  tmux select-window -t "$session:nvim"
}

create_session jslibs "$ROOT"

for dir in "$ROOT"/*/; do
  [ -d "$dir/.git" ] || continue

  name="$(basename "$dir")"
  create_session "jslib-$name" "$dir"
done
