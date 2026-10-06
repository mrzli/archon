#!/usr/bin/env bash

set -euo pipefail

component_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Runs test files concurrently; each file's output is printed as one block.
run_ruby_tests() {
  # shellcheck disable=SC2016 # The inner bash expands these variables.
  printf '%s\0' "$@" | xargs -0 -P 0 -n 1 bash -c 'output="$(ruby "$1" 2>&1)"; status=$?; printf "%s\n" "$output"; exit "$status"' _
}

printf '%s\n' 'Archon CLI Ruby tests'
run_ruby_tests "$component_root/tests/"*_test.rb

printf '\n%s\n' 'Archon CLI Ruby syntax checks'
while IFS= read -r -d '' path; do
  ruby -c "$path" > /dev/null
done < <(find "$component_root/lib" "$component_root/tests" -type f -name '*.rb' -print0)
ruby -c "$component_root/bin/archon" > /dev/null
ruby -c "$component_root/tests/bin/herdr" > /dev/null
