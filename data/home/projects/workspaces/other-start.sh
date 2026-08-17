#!/usr/bin/env bash

ROOT="$HOME/projects/personal"

PROJECTS=(
  "mrzli/docs"
  "mrzli/repos"
  "mrzli/archon"
  "mrzli/js-templates"
)

for project in "${PROJECTS[@]}"; do
  dir="$ROOT/$project"
  session="project-${project//\//-}"

  if tmux has-session -t "$session" 2>/dev/null; then
    continue
  fi

  tmux new-session -d -s "$session" -c "$dir" -n nvim
  tmux send-keys -t "$session:nvim" 'nvim .' Enter

  tmux new-window -t "$session" -c "$dir" -n codex
  tmux send-keys -t "$session:codex" 'codex resume --last' Enter

  tmux new-window -t "$session" -c "$dir" -n shell

  tmux select-window -t "$session:nvim"
done
