#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

printf '%s\n' 'Setup and WoW Ruby syntax checks'
while IFS= read -r -d '' path; do
  ruby -c "$path" > /dev/null
done < <(find "$repo_root/setup" "$repo_root/components/wow-setup" "$repo_root/tests" -type f -name '*.rb' -print0)

# Runs test files concurrently; each file's output is printed as one block.
run_ruby_tests() {
  # shellcheck disable=SC2016 # The inner bash expands these variables.
  printf '%s\0' "$@" | xargs -0 -P 0 -n 1 bash -c 'output="$(ruby "$1" 2>&1)"; status=$?; printf "%s\n" "$output"; exit "$status"' _
}

# The setup tests are the slowest group, so they run alongside the CLI verification.
setup_log="$(mktemp)"
trap 'rm -f -- "$setup_log"' EXIT
run_ruby_tests "$repo_root/setup/tests/"*_test.rb "$repo_root/components/wow-setup/tests/"*_test.rb > "$setup_log" 2>&1 &
setup_pid=$!

printf '\n%s\n' 'Archon CLI verification'
bash "$repo_root/components/archon-cli/tests/run.sh"

printf '\n%s\n' 'Setup and WoW tests'
setup_status=0
wait "$setup_pid" || setup_status=$?
cat "$setup_log"
(( setup_status == 0 ))

mapfile -t home_shell_paths < <(find "$repo_root/data/home" -type f -name '*.sh' -print | sort)
bash_check_paths=("$repo_root/tests/"*.sh "$repo_root/components/wow-setup/"*.sh "$repo_root/migrations/"*.sh
  "${home_shell_paths[@]}")
printf '\n%s\n' 'Additional Bash syntax checks'
for path in "${bash_check_paths[@]}"; do
  bash -n "$path"
done

printf '\n%s\n' 'Additional ShellCheck'
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${bash_check_paths[@]}"
else
  printf '%s\n' 'SKIP: ShellCheck is not available.'
fi

printf '\n%s\n' 'Archon verification passed.'
