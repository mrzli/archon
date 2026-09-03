#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"
home_source="$repo_root/data/home"
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

  cp -a "$home_source"/. "$home"/
}

test_repeated_overlay_copy() {
  local home="$temporary_root/overlay-home"
  local archon_output alias_output
  mkdir -p "$home"

  copy_home_overlay "$home"
  copy_home_overlay "$home"

  assert_exists "$home/.local/bin/archon" || return
  [[ -x "$home/.local/bin/archon" ]] || fail 'installed archon is not executable' || return
  [[ -L "$home/.local/bin/a" ]] || fail 'installed a is not a symbolic link' || return
  assert_equals archon "$(readlink "$home/.local/bin/a")" || return

  archon_output="$(HOME="$home" "$home/.local/bin/archon" --help)" || return
  alias_output="$(HOME="$home" "$home/.local/bin/a" --help)" || return
  assert_equals "$archon_output" "$alias_output" || return

  assert_exists "$home/.local/AGENTS.md" || return
  assert_exists "$home/.local/lib/archon/projects/AGENTS.md"
}

test_managed_library_replacement_scope() {
  local home="$temporary_root/replacement-home"
  local library="$home/.local/lib/archon"
  local sibling="$home/.local/lib/unrelated/keep"
  mkdir -p "$home"
  copy_home_overlay "$home"

  grep -qFx '.local/lib/archon' "$replace_directories" ||
    fail '.local/lib/archon is not a managed replacement directory' || return

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
