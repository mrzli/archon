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

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [ "$action" = start ]; then
  groups=(hubs flashcards jslibs misc-projects)
else
  groups=(misc-projects jslibs flashcards hubs)
fi

status=0

for group in "${groups[@]}"; do
  if ! "$script_dir/$group.sh" "$action"; then
    echo "Failed to $action tmux group: $group" >&2
    status=1
  fi
done

if [ "$action" = stop ] || [ "$status" -ne 0 ]; then
  exit "$status"
fi

if [ -n "$TMUX" ]; then
  if ! tmux switch-client -t workspaces; then
    echo "Failed to switch to tmux session: workspaces" >&2
    exit 1
  fi
elif ! tmux attach-session -t workspaces; then
  echo "Failed to attach to tmux session: workspaces" >&2
  exit 1
fi
