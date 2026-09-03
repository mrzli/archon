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

root="$HOME/projects/personal/mrzli-jslib"

create_session() {
  local session="$1"
  local directory="$2"

  tmux new-session -d -s "$session" -c "$directory" -n nvim || return
  tmux send-keys -t "$session:nvim" 'nvim .' Enter || return
  tmux new-window -t "$session" -c "$directory" -n codex || return
  tmux send-keys -t "$session:codex" 'codex resume --last' Enter || return
  tmux new-window -t "$session" -c "$directory" -n shell || return
  tmux select-window -t "$session:nvim"
}

if [ "$action" = start ]; then
  if [ ! -d "$root" ]; then
    echo "Skipping JavaScript libraries: directory does not exist: $root" >&2
    exit 0
  fi

  status=0

  for directory in "$root"/*/; do
    [ -d "$directory/.git" ] || continue

    name="$(basename "$directory")"
    session="jslib-$name"

    if tmux has-session -t "$session" 2>/dev/null; then
      continue
    fi

    if ! create_session "$session" "$directory"; then
      echo "Failed to start tmux session: $session" >&2
      status=1
    fi
  done

  exit "$status"
fi

if ! session_output="$(tmux list-sessions -F '#S' 2>&1)"; then
  case "$session_output" in
    *"no server running"*) exit 0 ;;
    *)
      echo "Failed to list tmux sessions: $session_output" >&2
      exit 1
      ;;
  esac
fi

status=0

while IFS= read -r session; do
  case "$session" in
    jslib-*)
      if ! tmux kill-session -t "$session"; then
        echo "Failed to stop tmux session: $session" >&2
        status=1
      fi
      ;;
  esac
done <<< "$session_output"

exit "$status"
