#!/usr/bin/env bash

set -euo pipefail

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

printf '%s\n' 'Archon CLI real tmux integration tests'
for path in "$test_dir/integration/"*_test.rb; do
  ruby "$path"
done
