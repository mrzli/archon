#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../../.." && pwd)"
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

  copy_home_overlay "$home" || return
  copy_archon_cli "$home"
}

test_repeated_overlay_copy() {
  local home="$temporary_root/overlay-home"
  local archon_output alias_output tree_after_first tree_after_second
  mkdir -p "$home"

  mkdir -p "$home/.local/lib/archon/commands/workspaces/tests" "$home/.local/lib/unrelated"
  printf '%s' 'user note' > "$home/.local/lib/archon/commands/workspaces/tests/user-note.txt"
  printf '%s' 'unrelated data' > "$home/.local/lib/unrelated/keep"

  install_home "$home" || return
  tree_after_first="$(find "$home" -printf '%P\t%y\t%l\n' | sort)"
  install_home "$home" || return
  tree_after_second="$(find "$home" -printf '%P\t%y\t%l\n' | sort)"

  assert_equals "$tree_after_first" "$tree_after_second" || return

  assert_exists "$home/.local/bin/archon" || return
  [[ -x "$home/.local/bin/archon" ]] || fail 'installed archon is not executable' || return
  [[ -L "$home/.local/bin/arc" ]] || fail 'installed arc is not a symbolic link' || return
  assert_equals archon "$(readlink "$home/.local/bin/arc")" || return

  archon_output="$(cd "$home" && HOME="$home" .local/bin/archon --help)" || return
  alias_output="$(cd "$home" && HOME="$home" .local/bin/arc --help)" || return
  assert_equals "$archon_output" "$alias_output" || return

  archon_output="$(cd "$home" && HOME="$home" .local/bin/archon workspaces list)" || return
  alias_output="$(cd "$home" && HOME="$home" .local/bin/arc w list)" || return
  assert_equals "$archon_output" "$alias_output" || return
  assert_equals 'No projects found under ~/projects/cloned or ~/projects/personal.' "$archon_output" || return
  assert_absent "$home/projects" || return

  mkdir -p "$home/projects/cloned/plain folder" "$home/projects/personal/owner/plain" || return
  archon_output="$(cd "$home" && HOME="$home" .local/bin/archon workspaces list)" || return
  assert_equals $'~/projects/cloned/plain folder\n~/projects/personal/owner/plain' "$archon_output" || return

  cmp -- "$archon_cli_source/bin/archon" "$home/.local/bin/archon" || return

  local expected_files installed_files path
  expected_files="$(cd "$archon_cli_source/lib" && find . -type f -name '*.rb' -printf '%P\n' | sort)" || return
  installed_files="$(cd "$home/.local/lib" && find archon -type f \
    ! -path archon/commands/workspaces/tests/user-note.txt -print | sort)" || return
  assert_equals "$expected_files" "$installed_files" || return
  while IFS= read -r path; do
    cmp -- "$archon_cli_source/lib/$path" "$home/.local/lib/$path" || return
  done <<< "$expected_files"

  assert_absent "$home/.local/AGENTS.md" || return
  assert_absent "$home/.local/tests" || return
  assert_equals 'user note' "$(cat "$home/.local/lib/archon/commands/workspaces/tests/user-note.txt")" || return
  assert_equals 'unrelated data' "$(cat "$home/.local/lib/unrelated/keep")"
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
