#!/usr/bin/env bash

set -euo pipefail

repo_root_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

if command -v ruby &>/dev/null; then
  exec ruby "$repo_root_dir/setup/main.rb" "$@"
else
  omarchy install dev-env ruby
  exec mise exec ruby -- ruby "$repo_root_dir/setup/main.rb" "$@"
fi
