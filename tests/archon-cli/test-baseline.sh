#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"
libs_source="${LIBS_SCRIPT:-$repo_root/data/home/projects/personal/mrzli-jslib/libs.mjs}"
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

assert_global_contract() {
  local script="$1"
  local home="$2"
  shift 2
  local command

  for command in '' help -h --help; do
    if [[ -z "$command" ]]; then
      capture_with_home "$home" node "$script"
    else
      capture_with_home "$home" node "$script" "$command"
    fi
    assert_equals 0 "$command_status" || return
    assert_contains "$command_output" 'Usage: ./' || return
    assert_contains "$command_output" 'Commands:' || return
  done

  capture_with_home "$home" node "$script" unknown
  assert_equals 1 "$command_status" || return
  assert_contains "$command_output" 'Unknown command: unknown' || return

  for command in "$@"; do
    capture_with_home "$home" node "$script" help "$command"
    assert_equals 0 "$command_status" || return
    assert_contains "$command_output" "Usage: ./${script##*/} $command" || return
  done

  capture_with_home "$home" node "$script" help unknown
  assert_equals 1 "$command_status" || return
  assert_contains "$command_output" 'Unknown command: unknown' || return

  capture_with_home "$home" node "$script" status --unexpected
  assert_equals 1 "$command_status" || return
  assert_contains "$command_output" 'Unexpected status option: --unexpected'
}

test_libraries_command_contract() {
  local fixture="$temporary_root/libs-contract"
  local home="$fixture/home"
  local script="$fixture/bin/libs.mjs"
  mkdir -p "$home/projects/personal/mrzli-jslib" "${script%/*}"
  cp "$libs_source" "$script"

  assert_global_contract \
    "$script" \
    "$home" \
    build delete graph prune remote status sync help
}

test_libraries_destructive_dry_runs() {
  local fixture="$temporary_root/libs-dry-run"
  local home="$fixture/home"
  local script="$fixture/bin/libs.mjs"
  local repository="$home/projects/personal/mrzli-jslib/example-library"
  mkdir -p "$repository/.git" "${script%/*}"
  cp "$libs_source" "$script"

  capture_with_home "$home" node "$script" delete --dry-run
  assert_equals 0 "$command_status" || return
  assert_contains "$command_output" 'Dry run; the following directories would be deleted:' || return
  assert_contains "$command_output" "$repository" || return
  assert_exists "$repository" || return

  : > "$ARCHON_TEST_GH_CALLS"
  capture_with_home "$home" node "$script" prune --dry-run
  assert_equals 0 "$command_status" || return
  assert_contains "$command_output" 'Dry run; the following directories would be deleted:' || return
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

run_test 'libraries command contract' test_libraries_command_contract
run_test 'libraries destructive dry-runs' test_libraries_destructive_dry_runs

printf '%s tests, %s failures\n' "$tests_run" "$tests_failed"
[[ "$tests_failed" -eq 0 ]]
