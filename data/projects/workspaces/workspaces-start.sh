#!/usr/bin/env bash

SESSION="workspaces"
DIR="$HOME/projects/workspaces"

mkdir -p "$DIR"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$DIR" -n shell
fi

if [ -n "$TMUX" ]; then
  tmux switch-client -t "$SESSION"
else
  tmux attach-session -t "$SESSION"
fi

