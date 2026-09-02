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

sessions=(workspaces projects libs)
directories=(
  "$HOME/projects/workspaces"
  "$HOME/projects/personal"
  "$HOME/projects/personal/mrzli-jslib"
)

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

    if ! tmux new-session -d -s "$session" -c "$directory" -n shell; then
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
