#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"
home_source="$repo_root/data/home"
home_copy_ignore="$repo_root/data/home-copy-ignore.txt"
replace_directories="$repo_root/data/home-replace-directories.txt"
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

test_repeated_overlay_copy() {
  local home="$temporary_root/overlay-home"
  local archon_output alias_output tree_after_first tree_after_second
  mkdir -p "$home"

  mkdir -p "$home/.local/lib/archon/workspaces/tests" "$home/.local/lib/unrelated"
  : > "$home/.local/lib/archon/workspaces/tests/user-note.txt"
  : > "$home/.local/lib/unrelated/keep"

  copy_home_overlay "$home"
  tree_after_first="$(find "$home" -printf '%P\t%y\t%l\n' | sort)"
  copy_home_overlay "$home"
  tree_after_second="$(find "$home" -printf '%P\t%y\t%l\n' | sort)"

  assert_equals "$tree_after_first" "$tree_after_second" || return

  assert_exists "$home/.local/bin/archon" || return
  [[ -x "$home/.local/bin/archon" ]] || fail 'installed archon is not executable' || return
  [[ -L "$home/.local/bin/a" ]] || fail 'installed a is not a symbolic link' || return
  assert_equals archon "$(readlink "$home/.local/bin/a")" || return

  archon_output="$(HOME="$home" "$home/.local/bin/archon" --help)" || return
  alias_output="$(HOME="$home" "$home/.local/bin/a" --help)" || return
  assert_equals "$archon_output" "$alias_output" || return

  assert_absent "$home/.local/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/libs/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/libs/README.md" || return
  assert_absent "$home/.local/lib/archon/projects/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/projects/README.md" || return
  assert_absent "$home/.local/lib/archon/workspaces/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/workspaces/README.md" || return

  local source_test
  for source_test in "$home_source/.local/lib/archon/workspaces/tests"/*; do
    assert_absent "$home/.local/lib/archon/workspaces/tests/${source_test##*/}" || return
  done

  assert_exists "$home/.local/lib/archon/cli.mjs" || return
  assert_exists "$home/.local/lib/archon/libs/src/libs.mjs" || return
  assert_exists "$home/.local/lib/archon/projects/src/projects.mjs" || return
  assert_exists "$home/.local/lib/archon/workspaces/src/workspaces.mjs" || return
  assert_exists "$home/.local/lib/archon/workspaces/tests/user-note.txt" || return
  assert_exists "$home/.local/lib/unrelated/keep"
}

test_managed_library_replacement_scope() {
  local home="$temporary_root/replacement-home"
  local library="$home/.local/lib/archon"
  local sibling="$home/.local/lib/unrelated/keep"
  mkdir -p "$home"
  copy_home_overlay "$home"

  grep -qFx '.local/lib/archon' "$replace_directories" ||
    fail '.local/lib/archon is not a managed replacement directory' || return
  if grep -qFx 'projects/workspaces' "$replace_directories"; then
    fail 'projects/workspaces remains a managed replacement directory'
    return
  fi

  mkdir -p "$library" "${sibling%/*}"
  : > "$library/stale.mjs"
  : > "$sibling"

  rm -rf -- "$library"
  copy_home_overlay "$home"

  assert_absent "$library/stale.mjs" || return
  assert_exists "$library/cli.mjs" || return
  assert_exists "$sibling"
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
run_test 'managed library replacement scope' test_managed_library_replacement_scope

printf '%s tests, %s failures\n' "$tests_run" "$tests_failed"
[[ "$tests_failed" -eq 0 ]]
