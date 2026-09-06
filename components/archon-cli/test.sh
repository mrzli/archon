#!/usr/bin/env bash

set -euo pipefail

component_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

bun "$component_root/scripts/build.ts"

mapfile -t bun_tests < <(
  find "$component_root/tests" -type f -name '*.test.ts' -print | sort
)

printf '%s\n' 'Archon CLI Bun tests'
# Run files separately and sequentially to preserve process-global isolation.
for path in "${bun_tests[@]}"; do
  bun test "$path"
done

mapfile -t bun_check_paths < <(
  find \
    "$component_root/dist/lib/archon" \
    -type f -name '*.js' -print | sort
)
bun_check_paths=(
  "$component_root/bin/archon"
  "$component_root/dist/bin/archon"
  "${bun_check_paths[@]}"
)

printf '\n%s\n' 'Archon CLI Bun syntax checks'
for path in "${bun_check_paths[@]}"; do
  bun build --no-bundle --target=bun "$path" > /dev/null
done

printf '\n%s\n' 'Archon CLI workspace adapter tests'
bash "$component_root/tests/test-workspaces-adapter.sh"
