#!/usr/bin/env bash

FE="$HOME/projects/personal/mrzli/flashcards-fe"
BE="$HOME/projects/personal/mrzli/flashcards-be"

create_session() {
  local name="$1"
  local dir="$2"
  local dev_cmd="$3"

  if tmux has-session -t "$name" 2>/dev/null; then
    return
  fi

  tmux new-session -d -s "$name" -c "$dir" -n nvim
  tmux send-keys -t "$name:nvim" 'nvim .' Enter

  tmux new-window -t "$name" -c "$dir" -n codex
  tmux send-keys -t "$name:codex" 'codex resume --last' Enter

  tmux new-window -t "$name" -c "$dir" -n dev
  tmux send-keys -t "$name:dev" "$dev_cmd" Enter

  tmux new-window -t "$name" -c "$dir" -n shell

  tmux select-window -t "$name:nvim"
}

create_session flashcards-fe "$FE" "bun run dev"
create_session flashcards-be "$BE" "pnpm run dev"
