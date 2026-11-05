#!/usr/bin/env bash

set -euo pipefail

repo_root_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

exec ruby "$repo_root_dir/setup/main.rb" "$@"
