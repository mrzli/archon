#!/usr/bin/env bash

set -euo pipefail

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"

printf '%s\n' 'Archon CLI component tests'
bash "$repo_root/components/archon-cli/test.sh"

printf '\n%s\n' 'Archon CLI installation-layout tests'
bash "$test_dir/test-install-layout.sh"

mapfile -t bash_check_paths < <(
  find \
    "$repo_root/components/archon-cli" \
    "$repo_root/tests/archon-cli" \
    -type f -name '*.sh' -print | sort
)
bash_check_paths=(
  "$repo_root/setup.sh"
  "${bash_check_paths[@]}"
)

printf '\n%s\n' 'Archon CLI Bash syntax checks'
for path in "${bash_check_paths[@]}"; do
  bash -n "$path"
done

printf '\n%s\n' 'Archon CLI ShellCheck'
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${bash_check_paths[@]}"
else
  printf '%s\n' 'SKIP: ShellCheck is not available.'
fi

printf '\n%s\n' 'Git whitespace validation'
git -C "$repo_root" diff --check

printf '\n%s\n' 'Archon CLI verification passed.'
