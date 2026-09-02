#!/usr/bin/env bash

if [ "$#" -ne 1 ]; then
  echo "Usage: $(basename "$0") {start|stop}" >&2
  exit 2
fi

action="$1"
case "$action" in
  start | stop) ;;
  *)
    echo "Usage: $(basename "$0") {start|stop}" >&2
    exit 2
    ;;
esac

sessions=(flashcards-fe flashcards-be)
directories=(
  "$HOME/projects/personal/mrzli/flashcards-fe"
  "$HOME/projects/personal/mrzli/flashcards-be"
)
dev_commands=("bun run dev" "pnpm run dev")

create_session() {
  local session="$1"
  local directory="$2"
  local dev_command="$3"

  tmux new-session -d -s "$session" -c "$directory" -n nvim || return
  tmux send-keys -t "$session:nvim" 'nvim .' Enter || return
  tmux new-window -t "$session" -c "$directory" -n codex || return
  tmux send-keys -t "$session:codex" 'codex resume --last' Enter || return
  tmux new-window -t "$session" -c "$directory" -n dev || return
  tmux send-keys -t "$session:dev" "$dev_command" Enter || return
  tmux new-window -t "$session" -c "$directory" -n shell || return
  tmux select-window -t "$session:nvim"
}

status=0

for index in "${!sessions[@]}"; do
  session="${sessions[$index]}"
  directory="${directories[$index]}"

  if [ "$action" = start ]; then
    if [ ! -d "$directory" ]; then
      echo "Skipping $session: directory does not exist: $directory" >&2
      continue
    fi

    if tmux has-session -t "$session" 2>/dev/null; then
      continue
    fi

    if ! create_session "$session" "$directory" "${dev_commands[$index]}"; then
      echo "Failed to start tmux session: $session" >&2
      status=1
    fi
  elif tmux has-session -t "$session" 2>/dev/null; then
    if ! tmux kill-session -t "$session"; then
      echo "Failed to stop tmux session: $session" >&2
      status=1
    fi
  fi
done

exit "$status"
