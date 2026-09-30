#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"
archon_cli_source="$repo_root/components/archon-cli"
home_source="$repo_root/data/home"
home_copy_ignore="$repo_root/data/home-copy-ignore.txt"
temporary_root="$(mktemp -d)"

cleanup() {
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

assert_exists() {
  [[ -e "$1" || -L "$1" ]] || fail "expected path to exist: $1"
}

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "expected path to be absent: $1"
}

assert_equals() {
  local expected="$1"
  local actual="$2"

  [[ "$actual" == "$expected" ]] || fail "expected '$expected', got '$actual'"
}

copy_home_overlay() {
  local home="$1"

  rsync -a --exclude-from="$home_copy_ignore" "$home_source"/ "$home"/
}

copy_archon_cli() {
  local home="$1"

  ruby -r "$repo_root/setup/setup.rb" -e 'install_archon_cli(*ARGV)' "$repo_root" "$home"
}

install_home() {
  local home="$1"

  copy_home_overlay "$home"
  copy_archon_cli "$home"
}

test_repeated_overlay_copy() {
  local home="$temporary_root/overlay-home"
  local archon_output alias_output tree_after_first tree_after_second
  mkdir -p "$home"

  mkdir -p "$home/.local/lib/archon/commands/workspaces_tmux/tests" "$home/.local/lib/unrelated"
  : > "$home/.local/lib/archon/commands/workspaces_tmux/tests/user-note.txt"
  : > "$home/.local/lib/unrelated/keep"

  install_home "$home"
  tree_after_first="$(find "$home" -printf '%P\t%y\t%l\n' | sort)"
  install_home "$home"
  tree_after_second="$(find "$home" -printf '%P\t%y\t%l\n' | sort)"

  assert_equals "$tree_after_first" "$tree_after_second" || return

  assert_exists "$home/.local/bin/archon" || return
  [[ -x "$home/.local/bin/archon" ]] || fail 'installed archon is not executable' || return
  [[ -L "$home/.local/bin/arc" ]] || fail 'installed arc is not a symbolic link' || return
  assert_equals archon "$(readlink "$home/.local/bin/arc")" || return

  archon_output="$(cd "$home" && HOME="$home" .local/bin/archon --help)" || return
  alias_output="$(cd "$home" && HOME="$home" .local/bin/arc --help)" || return
  assert_equals "$archon_output" "$alias_output" || return

  assert_absent "$home/.local/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/commands/libs/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/commands/libs/README.md" || return
  assert_absent "$home/.local/lib/archon/commands/projects/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/commands/projects/README.md" || return
  assert_absent "$home/.local/lib/archon/commands/workspaces_tmux/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/commands/workspaces_tmux/README.md" || return

  local source_test
  for source_test in "$archon_cli_source/tests"/*_test.rb; do
    assert_absent "$home/.local/lib/archon/commands/workspaces_tmux/tests/${source_test##*/}" || return
  done

  assert_exists "$home/.local/lib/archon/cli.rb" || return
  assert_exists "$home/.local/lib/archon/commands/admin/admin.rb" || return
  assert_absent "$home/.local/lib/archon/commands/admin/README.md" || return
  archon_output="$(cd "$home" && HOME="$home" .local/bin/archon admin --help)" || return
  alias_output="$(cd "$home" && HOME="$home" .local/bin/arc a --help)" || return
  assert_equals "$archon_output" "$alias_output" || return
  local unexpected_files
  unexpected_files="$(find "$home/.local/lib/archon" -type f ! -name '*.rb' ! -name user-note.txt)"
  assert_equals '' "$unexpected_files" || return
  assert_absent "$home/.local/package.json" || return
  assert_absent "$home/.local/node_modules" || return
  assert_absent "$home/.local/dist" || return
  assert_exists "$home/.local/lib/archon/commands/libs/build.rb" || return
  assert_exists "$home/.local/lib/archon/commands/libs/libs.rb" || return
  assert_exists "$home/.local/lib/archon/commands/projects/github_inventory.rb" || return
  assert_exists "$home/.local/lib/archon/commands/projects/projects.rb" || return
  assert_exists "$home/.local/lib/archon/commands/workspaces_tmux/workspaces.rb" || return
  assert_absent "$home/.local/lib/archon/commands/workspaces/workspaces.rb" || return
  assert_exists "$home/.local/lib/archon/commands/workspaces_herdr/workspaces_herdr.rb" || return
  assert_absent "$home/.local/lib/archon/commands/workspaces_herdr/README.md" || return
  archon_output="$(cd "$home" && HOME="$home" .local/bin/archon workspaces --help)" || return
  alias_output="$(cd "$home" && HOME="$home" .local/bin/arc w --help)" || return
  assert_equals "$archon_output" "$alias_output" || return
  [[ "$archon_output" == 'Usage: archon workspaces '* ]] || fail 'unexpected Herdr workspace help' || return
  archon_output="$(cd "$home" && HOME="$home" .local/bin/archon workspaces-tmux --help)" || return
  alias_output="$(cd "$home" && HOME="$home" .local/bin/arc wt --help)" || return
  assert_equals "$archon_output" "$alias_output" || return
  [[ "$archon_output" == 'Usage: archon workspaces-tmux '* ]] || fail 'unexpected tmux workspace help' || return
  assert_exists "$home/.local/lib/archon/commands/workspaces_tmux/tests/user-note.txt" || return
  assert_exists "$home/.local/lib/unrelated/keep"
}

tests_run=0
tests_failed=0

run_test() {
  local name="$1"
  shift
  tests_run=$((tests_run + 1))

  if "$@"; then
    printf 'PASS: %s\n' "$name"
  else
    printf 'FAIL: %s\n' "$name" >&2
    tests_failed=$((tests_failed + 1))
  fi
}

run_test 'repeated home-overlay copy' test_repeated_overlay_copy

printf '%s tests, %s failures\n' "$tests_run" "$tests_failed"
[[ "$tests_failed" -eq 0 ]]
