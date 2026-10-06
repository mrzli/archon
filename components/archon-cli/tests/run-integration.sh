#!/usr/bin/env bash

set -euo pipefail

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

printf '%s\n' 'Archon CLI real Herdr and tmux integration tests'
status=0
for path in "$test_dir/integration/"*_test.rb; do
  ruby "$path" || status=1
done
exit "$status"
