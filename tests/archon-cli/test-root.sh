#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"
archon="${ARCHON_COMMAND:-$repo_root/data/home/.local/bin/archon}"
temporary_root="$(mktemp -d)"

cleanup() {
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT

export PATH="$test_dir/bin:$PATH"
export ARCHON_TEST_GH_CALLS="$temporary_root/gh-calls"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

capture() {
  command_output="$("$@" 2>&1)"
  command_status=$?
}

capture_with_home() {
  local home="$1"
  shift

  command_output="$(HOME="$home" "$@" 2>&1)"
  command_status=$?
}

assert_equals() {
  local expected="$1"
  local actual="$2"

  [[ "$actual" == "$expected" ]] || fail "expected '$expected', got '$actual'"
}

assert_contains() {
  local text="$1"
  local expected="$2"

  [[ "$text" == *"$expected"* ]] || fail "output does not contain: $expected"
}

assert_exists() {
  [[ -e "$1" ]] || fail "expected path to exist: $1"
}

test_help() {
  local argument

  for argument in help -h --help; do
    capture "$archon" "$argument"
    assert_equals 0 "$command_status" || return
    assert_contains "$command_output" 'Usage: archon <command> [options]' || return
    assert_contains "$command_output" 'libs        Manage local JavaScript libraries' || return
    assert_contains "$command_output" 'projects    Manage personal project repositories' || return
    assert_contains "$command_output" 'workspaces  Manage tmux workspace sessions' || return
  done
}

test_missing_command() {
  capture "$archon"
  assert_equals 2 "$command_status" || return
  assert_contains "$command_output" 'Missing command.' || return
  assert_contains "$command_output" 'Usage: archon <command> [options]'
}

test_unknown_command() {
  capture "$archon" unknown
  assert_equals 2 "$command_status" || return
  assert_contains "$command_output" 'Unknown command: unknown' || return
  assert_contains "$command_output" 'Usage: archon <command> [options]'
}

test_unexpected_help_argument() {
  capture "$archon" help extra
  assert_equals 2 "$command_status" || return
  assert_contains "$command_output" 'Unexpected help argument: extra' || return
  assert_contains "$command_output" 'Usage: archon <command> [options]'
}

test_projects_dispatch() {
  local home="$temporary_root/projects-home"
  local repository="$home/projects/personal/example-owner/example-project"
  mkdir -p "$repository/.git"

  capture_with_home "$home" "$archon" projects --help
  assert_equals 0 "$command_status" || return
  assert_contains "$command_output" 'Usage: ./projects.mjs <command>' || return

  capture_with_home "$home" "$archon" projects unknown
  assert_equals 1 "$command_status" || return
  assert_contains "$command_output" 'Unknown command: unknown' || return

  capture_with_home "$home" "$archon" projects delete --dry-run
  assert_equals 0 "$command_status" || return
  assert_contains "$command_output" "$repository" || return
  assert_exists "$repository" || return

  : > "$ARCHON_TEST_GH_CALLS"
  capture_with_home "$home" "$archon" projects prune --dry-run
  assert_equals 0 "$command_status" || return
  assert_contains "$command_output" "$repository" || return
  assert_exists "$repository" || return
  assert_contains "$(<"$ARCHON_TEST_GH_CALLS")" 'user/repos?affiliation=owner&visibility=all&per_page=100'
}

test_libraries_dispatch() {
  local home="$temporary_root/libs-home"
  local repository="$home/projects/personal/mrzli-jslib/example-library"
  mkdir -p "$repository/.git"

  capture_with_home "$home" "$archon" libs --help
  assert_equals 0 "$command_status" || return
  assert_contains "$command_output" 'Usage: ./libs.mjs <command>' || return

  capture_with_home "$home" "$archon" libs unknown
  assert_equals 1 "$command_status" || return
  assert_contains "$command_output" 'Unknown command: unknown' || return

  capture_with_home "$home" "$archon" libs graph
  assert_equals 1 "$command_status" || return
  assert_contains "$command_output" 'example-library/package.json could not be read' || return

  capture_with_home "$home" "$archon" libs delete --dry-run
  assert_equals 0 "$command_status" || return
  assert_contains "$command_output" "$repository" || return
  assert_exists "$repository" || return

  : > "$ARCHON_TEST_GH_CALLS"
  capture_with_home "$home" "$archon" libs prune --dry-run
  assert_equals 0 "$command_status" || return
  assert_contains "$command_output" "$repository" || return
  assert_exists "$repository" || return
  assert_contains "$(<"$ARCHON_TEST_GH_CALLS")" 'repo list mrzli-jslib'
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

run_test 'root help' test_help
run_test 'missing root command' test_missing_command
run_test 'unknown root command' test_unknown_command
run_test 'unexpected root help argument' test_unexpected_help_argument
run_test 'libraries command dispatch' test_libraries_dispatch
run_test 'projects command dispatch' test_projects_dispatch

printf '%s tests, %s failures\n' "$tests_run" "$tests_failed"
[[ "$tests_failed" -eq 0 ]]
