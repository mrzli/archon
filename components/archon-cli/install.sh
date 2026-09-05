#!/usr/bin/env bash

set -euo pipefail

if (($# != 1)); then
  printf 'Usage: %s HOME_DIRECTORY\n' "${0##*/}" >&2
  exit 2
fi

component_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
home_dir="$1"

mkdir -p "$home_dir/.local/bin" "$home_dir/.local/lib/archon"
rsync -a --exclude='*.md' "$component_root/lib/archon"/ "$home_dir/.local/lib/archon"/
install -m 755 "$component_root/bin/archon" "$home_dir/.local/bin/archon"
ln -sfn archon "$home_dir/.local/bin/a"
