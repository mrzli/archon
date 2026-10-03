#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

printf '%s\n' 'Setup and WoW Ruby syntax checks'
while IFS= read -r -d '' path; do
  ruby -c "$path" > /dev/null
done < <(find "$repo_root/setup" "$repo_root/components/wow-setup" "$repo_root/tests" -type f -name '*.rb' -print0)

printf '\n%s\n' 'Setup and WoW tests'
for path in "$repo_root/setup/tests/"*_test.rb "$repo_root/components/wow-setup/tests/"*_test.rb; do
  ruby "$path"
done

printf '\n%s\n' 'Archon CLI verification'
bash "$repo_root/components/archon-cli/tests/run.sh"

bash_check_paths=("$repo_root/tests/"*.sh "$repo_root/components/wow-setup/"*.sh)
printf '\n%s\n' 'Additional Bash syntax checks'
for path in "${bash_check_paths[@]}"; do
  bash -n "$path"
done

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${bash_check_paths[@]}"
fi

printf '\n%s\n' 'Archon verification passed.'
