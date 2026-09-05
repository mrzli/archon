#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"
archon_cli_source="$repo_root/components/archon-cli"
home_source="$repo_root/data/home"
home_copy_ignore="$repo_root/data/home-copy-ignore.txt"
migration="$repo_root/migrations/archon-cli.sh"
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

copy_archon_cli() {
  local home="$1"

  mkdir -p "$home/.local/bin" "$home/.local/lib/archon"
  rsync -a --exclude='*.md' "$archon_cli_source/lib/archon"/ "$home/.local/lib/archon"/
  install -m 755 "$archon_cli_source/bin/archon" "$home/.local/bin/archon"
  ln -sfn archon "$home/.local/bin/arc"
}

test_requires_installed_replacements() {
  local home="$temporary_root/missing-replacement-home"
  local output status
  mkdir -p "$home/projects/personal"
  : > "$home/projects/personal/projects.mjs"

  output="$(HOME="$home" "$migration" 2>&1)"
  status=$?

  [[ "$status" -eq 1 ]] || fail "expected status 1, got $status" || return
  [[ "$output" == *'Replacement is not installed:'* ]] ||
    fail 'missing replacement was not reported' || return
  assert_exists "$home/projects/personal/projects.mjs"
}

test_removes_only_legacy_files() {
  local home="$temporary_root/migration-home"
  local relative_file
  local legacy_files=(
    projects/personal/projects.mjs
    projects/personal/mrzli-jslib/libs.mjs
    projects/workspaces/all.sh
    projects/workspaces/flashcards.sh
    projects/workspaces/hubs.sh
    projects/workspaces/jslibs.sh
    projects/workspaces/misc-projects.sh
  )
  mkdir -p "$home"
  rsync -a --exclude-from="$home_copy_ignore" "$home_source"/ "$home"/
  copy_archon_cli "$home"

  mkdir -p \
    "$home/projects/personal/example-owner/example-project" \
    "$home/projects/personal/mrzli-jslib" \
    "$home/projects/workspaces"
  : > "$home/projects/personal/README.md"
  : > "$home/projects/personal/AGENTS.md"
  : > "$home/projects/personal/example-owner/example-project/keep"
  : > "$home/projects/personal/mrzli-jslib/README.md"
  : > "$home/projects/personal/mrzli-jslib/AGENTS.md"
  : > "$home/projects/personal/mrzli-jslib/keep"
  : > "$home/projects/workspaces/keep"

  for relative_file in "${legacy_files[@]}"; do
    : > "$home/$relative_file"
  done

  HOME="$home" "$migration" >/dev/null || return
  HOME="$home" "$migration" >/dev/null || return

  for relative_file in "${legacy_files[@]}"; do
    assert_absent "$home/$relative_file" || return
  done

  assert_exists "$home/projects/personal/README.md" || return
  assert_exists "$home/projects/personal/AGENTS.md" || return
  assert_exists "$home/projects/personal/example-owner/example-project/keep" || return
  assert_exists "$home/projects/personal/mrzli-jslib/README.md" || return
  assert_exists "$home/projects/personal/mrzli-jslib/AGENTS.md" || return
  assert_exists "$home/projects/personal/mrzli-jslib/keep" || return
  assert_exists "$home/projects/workspaces/keep"
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

run_test 'requires installed replacements' test_requires_installed_replacements
run_test 'removes only legacy files repeat-safely' test_removes_only_legacy_files

printf '%s tests, %s failures\n' "$tests_run" "$tests_failed"
[[ "$tests_failed" -eq 0 ]]
