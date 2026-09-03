#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"
archon="${ARCHON_COMMAND:-$repo_root/data/home/.local/bin/archon}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

capture() {
  command_output="$("$@" 2>&1)"
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

printf '%s tests, %s failures\n' "$tests_run" "$tests_failed"
[[ "$tests_failed" -eq 0 ]]
