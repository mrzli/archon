#!/usr/bin/env bash

set -euo pipefail

component_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

node "$component_root/scripts/build.mjs"

mapfile -t node_tests < <(
  find "$component_root/tests" -type f -name '*.test.mjs' -print | sort
)

printf '%s\n' 'Archon CLI Node tests'
node --test --test-concurrency=1 "${node_tests[@]}"

mapfile -t node_check_paths < <(
  find \
    "$component_root/src" \
    "$component_root/scripts" \
    "$component_root/dist/lib/archon" \
    "$component_root/tests" \
    -type f -name '*.mjs' -print | sort
)
node_check_paths=(
  "$component_root/bin/archon"
  "$component_root/dist/bin/archon"
  "${node_check_paths[@]}"
)

printf '\n%s\n' 'Archon CLI Node syntax checks'
for path in "${node_check_paths[@]}"; do
  node --check "$path"
done
