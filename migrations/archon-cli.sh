#!/usr/bin/env bash

set -euo pipefail

replacement_files=(
  .local/bin/archon
  .local/lib/archon/commands/libs/libs.mjs
  .local/lib/archon/commands/projects/projects.mjs
  .local/lib/archon/commands/workspaces/workspaces.mjs
)

legacy_files=(
  projects/personal/projects.mjs
  projects/personal/mrzli-jslib/libs.mjs
  projects/workspaces/all.sh
  projects/workspaces/flashcards.sh
  projects/workspaces/hubs.sh
  projects/workspaces/jslibs.sh
  projects/workspaces/misc-projects.sh
)

for relative_file in "${replacement_files[@]}"; do
  if [[ ! -f "$HOME/$relative_file" ]]; then
    printf 'Replacement is not installed: ~/%s\n' "$relative_file" >&2
    printf 'Run setup.sh before this migration.\n' >&2
    exit 1
  fi
done

status=0

for relative_file in "${legacy_files[@]}"; do
  target="$HOME/$relative_file"

  if [[ -L "$target" || -f "$target" ]]; then
    rm -f -- "$target"
    printf 'Removed ~/%s\n' "$relative_file"
  elif [[ -e "$target" ]]; then
    printf 'Refusing to remove non-file path: ~/%s\n' "$relative_file" >&2
    status=1
  else
    printf 'Already absent: ~/%s\n' "$relative_file"
  fi
done

exit "$status"
