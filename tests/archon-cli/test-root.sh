#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"
archon="${ARCHON_COMMAND:-$repo_root/data/home/.local/bin/archon}"
libs_module="$repo_root/data/home/.local/lib/archon/libs/src/libs.mjs"
module_harness="$test_dir/run-module.mjs"
projects_module="$repo_root/data/home/.local/lib/archon/projects/src/projects.mjs"
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

initialize_repository() {
  local directory="$1"

  mkdir -p "$directory"
  git init -q -b main "$directory"
  git -C "$directory" config user.email test@example.com
  git -C "$directory" config user.name 'Archon Test'
  printf 'initial\n' > "$directory/tracked.txt"
  git -C "$directory" add tracked.txt
  git -C "$directory" commit -qm initial
}

add_repository_state() {
  local directory="$1"

  printf 'stashed\n' >> "$directory/tracked.txt"
  git -C "$directory" stash push -qm test-stash
  printf 'unstaged\n' >> "$directory/tracked.txt"
  printf 'staged\n' > "$directory/staged.txt"
  printf 'untracked\n' > "$directory/untracked.txt"
  git -C "$directory" add staged.txt
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

test_workspaces_dispatch_validation() {
  capture "$archon" workspaces --help
  assert_equals 0 "$command_status" || return
  assert_contains "$command_output" 'Usage: archon workspaces <start|stop> [options]' || return
  assert_contains "$command_output" '-g, --group <group>' || return

  capture "$archon" workspaces
  assert_equals 2 "$command_status" || return
  assert_contains "$command_output" 'Missing workspace action.' || return

  capture "$archon" workspaces launch
  assert_equals 2 "$command_status" || return
  assert_contains "$command_output" 'Unknown workspace action: launch' || return

  capture "$archon" workspaces start --group hubs
  assert_equals 2 "$command_status" || return
  assert_contains "$command_output" 'Invalid workspace options: --group hubs'
}

test_projects_dispatch() {
  local home="$temporary_root/projects-home"
  local repository="$home/projects/personal/example-owner/example-project"
  local command
  mkdir -p "$repository/.git"

  capture_with_home "$home" "$archon" projects --help
  assert_equals 0 "$command_status" || return
  assert_contains "$command_output" 'Usage: archon projects <command>' || return

  for command in delete prune remote status sync help; do
    capture_with_home "$home" "$archon" projects help "$command"
    assert_equals 0 "$command_status" || return
    assert_contains "$command_output" "Usage: archon projects $command" || return
  done

  capture_with_home "$home" "$archon" projects unknown
  assert_equals 2 "$command_status" || return
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
  local command
  mkdir -p "$repository/.git"

  capture_with_home "$home" "$archon" libs --help
  assert_equals 0 "$command_status" || return
  assert_contains "$command_output" 'Usage: archon libs <command>' || return

  for command in build delete graph prune remote status sync help; do
    capture_with_home "$home" "$archon" libs help "$command"
    assert_equals 0 "$command_status" || return
    assert_contains "$command_output" "Usage: archon libs $command" || return
  done

  capture_with_home "$home" "$archon" libs unknown
  assert_equals 2 "$command_status" || return
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

test_direct_module_dispatch() {
  local home="$temporary_root/module-home"
  local repository="$home/projects/personal/example-owner/example-project"
  local library="$home/projects/personal/mrzli-jslib/example-library"
  local archon_output archon_status module_output module_status
  mkdir -p "$repository/.git" "$library/.git"

  capture node "$module_harness" "$projects_module" --import-only
  assert_equals 0 "$command_status" || return
  assert_equals '' "$command_output" || return

  capture node "$module_harness" "$libs_module" --import-only
  assert_equals 0 "$command_status" || return
  assert_equals '' "$command_output" || return

  capture_with_home "$home" "$archon" projects delete --dry-run
  archon_output="$command_output"
  archon_status="$command_status"
  capture_with_home "$home" node "$module_harness" "$projects_module" delete --dry-run
  module_output="$command_output"
  module_status="$command_status"
  assert_equals "$archon_status" "$module_status" || return
  assert_equals "$archon_output" "$module_output" || return

  capture_with_home "$home" "$archon" libs delete --dry-run
  archon_output="$command_output"
  archon_status="$command_status"
  capture_with_home "$home" node "$module_harness" "$libs_module" delete --dry-run
  module_output="$command_output"
  module_status="$command_status"
  assert_equals "$archon_status" "$module_status" || return
  assert_equals "$archon_output" "$module_output"
}

test_repository_status() {
  local home="$temporary_root/status-home"
  local projects_root="$home/projects/personal"
  local libs_root="$projects_root/mrzli-jslib"
  local project_clean="$projects_root/example/clean"
  local project_changed="$projects_root/example/changed"
  local library_clean="$libs_root/clean"
  local library_changed="$libs_root/changed"

  initialize_repository "$project_clean"
  initialize_repository "$project_changed"
  initialize_repository "$library_clean"
  initialize_repository "$library_changed"
  add_repository_state "$project_changed"
  add_repository_state "$library_changed"

  mkdir -p \
    "$projects_root/example/not-a-repository" \
    "$projects_root/broken-owner/broken" \
    "$libs_root/broken" \
    "$libs_root/not-a-repository/nested"
  : > "$projects_root/broken-owner/broken/.git"
  : > "$libs_root/broken/.git"
  initialize_repository "$libs_root/not-a-repository/nested"
  git -C "$project_clean" remote add origin "$temporary_root/missing-remote"
  git -C "$library_clean" remote add origin "$temporary_root/missing-remote"

  capture_with_home "$home" "$archon" projects status
  assert_equals 1 "$command_status" || return
  assert_contains "$command_output" 'example/changed' || return
  assert_contains "$command_output" 'staged: 1, unstaged: 1, untracked: 1' || return
  assert_contains "$command_output" 'stash: 1' || return
  assert_contains "$command_output" 'broken-owner/broken  ERROR:' || return
  [[ "$command_output" != *'not-a-repository'* ]] || fail 'projects inventory included a non-repository' || return

  capture_with_home "$home" "$archon" libs status
  assert_equals 1 "$command_status" || return
  assert_contains "$command_output" 'changed' || return
  assert_contains "$command_output" 'broken' || return
  assert_contains "$command_output" 'ERROR:' || return
  [[ "$command_output" != *'not-a-repository'* ]] || fail 'libs inventory included a non-repository' || return

  capture_with_home "$home" "$archon" projects status --fetch
  assert_equals 1 "$command_status" || return
  assert_contains "$command_output" 'warnings: fetch failed:' || return
  capture_with_home "$home" "$archon" libs status --fetch
  assert_equals 1 "$command_status" || return
  assert_contains "$command_output" 'warnings: fetch failed:'
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
run_test 'direct module dispatch' test_direct_module_dispatch
run_test 'projects command dispatch' test_projects_dispatch
run_test 'repository status' test_repository_status
run_test 'workspaces dispatch validation' test_workspaces_dispatch_validation

printf '%s tests, %s failures\n' "$tests_run" "$tests_failed"
[[ "$tests_failed" -eq 0 ]]
