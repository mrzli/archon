#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/workspaces-start.sh"
"$SCRIPT_DIR/flashcards-start.sh"
"$SCRIPT_DIR/jslibs-start.sh"
"$SCRIPT_DIR/other-start.sh"

if [ -n "$TMUX" ]; then
  tmux switch-client -t workspaces
else
  tmux attach-session -t workspaces
fi
