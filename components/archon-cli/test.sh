#!/usr/bin/env bash

set -euo pipefail

component_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

printf '%s\n' 'Archon CLI Ruby tests'
for path in "$component_root/tests/"*_test.rb; do
  ruby "$path"
done

printf '\n%s\n' 'Archon CLI Ruby syntax checks'
while IFS= read -r -d '' path; do
  ruby -c "$path" > /dev/null
done < <(find "$component_root/lib" "$component_root/tests" -type f -name '*.rb' -print0)
ruby -c "$component_root/bin/archon" > /dev/null
ruby -c "$component_root/tests/bin/herdr" > /dev/null
