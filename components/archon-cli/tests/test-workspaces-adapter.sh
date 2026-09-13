#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
component_root="$(cd -- "$test_dir/.." && pwd)"
bun "$component_root/scripts/build.ts" || exit 1
archon="$component_root/dist/bin/archon"
export PATH="$test_dir/bin:$PATH"

run_case() (
  temporary_root="$(mktemp -d)" || exit
  trap 'rm -rf -- "$temporary_root"' EXIT
  fixture_home="$temporary_root/home"
  export TMW_TMUX_STATE="$temporary_root/tmux"
  unset TMUX TMW_TMUX_FAIL_COMMAND
  mkdir -p "$fixture_home" "$TMW_TMUX_STATE" || exit
  "$@"
)

run_archon() {
  env HOME="$fixture_home" "$archon" "$@" < /dev/null
}

run_terminal_archon() {
  local command
  printf -v command '%q ' "$archon" "$@"
  env HOME="$fixture_home" SHELL=/bin/bash timeout 15s \
    script --quiet --return --command "$command" /dev/null < /dev/null
}

assert_attachment() {
  local actual
  actual="$(cat "$TMW_TMUX_STATE/attachments")" || return
  [[ "$actual" == "=$1" ]] || fail "unexpected attachments: $actual"
}

assert_sessions() {
  local actual expected
  actual="$(find "$TMW_TMUX_STATE/sessions" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)"
  expected="$(printf '%s\n' "$@" | sort)"
  [[ "$actual" == "$expected" ]] || fail "unexpected session set: $actual"
}

assert_no_attachment() {
  [[ -e "$TMW_TMUX_STATE/calls" ]] || return 0
  if grep -Eq -- 'tmux (attach-session|switch-client)' "$TMW_TMUX_STATE/calls"; then
    fail 'non-interactive command unexpectedly attached or switched clients'
    return 1
  fi
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

create_fixtures() {
  mkdir -p \
    "$fixture_home/projects/personal/mrzli-jslib/example/.git" \
    "$fixture_home/projects/personal/mrzli/flashcards-fe" \
    "$fixture_home/projects/personal/mrzli/flashcards-be" \
    "$fixture_home/projects/personal/mrzli/archon" \
    "$fixture_home/projects/personal/mrzli/docs" \
    "$fixture_home/projects/personal/mrzli/js-templates" \
    "$fixture_home/projects/personal/mrzli/learning" \
    "$fixture_home/projects/personal/mrzli/mrzli.github.io" \
    "$fixture_home/projects/personal/mrzli/repos" \
    "$fixture_home/projects/personal/mrzli/skills"
}

test_named_group() {
  create_fixtures || return

  run_archon workspaces start --group flashcards || return
  assert_sessions flashcards-fe flashcards-be || return

  run_archon workspaces stop -g flashcards || return
  assert_sessions || return
  assert_no_attachment
}

test_aggregate_groups() {
  create_fixtures || return

  run_archon workspaces start || return
  assert_sessions main flashcards-fe flashcards-be jslib-example \
    project-mrzli-archon project-mrzli-docs project-mrzli-js-templates project-mrzli-learning project-mrzli-mrzli-github-io project-mrzli-repos project-mrzli-skills || return
  run_archon workspaces stop || return
  assert_sessions || return
  assert_no_attachment
}

test_terminal_aggregate() {
  create_fixtures || return
  run_terminal_archon workspaces start || return
  assert_attachment main || return
  assert_sessions main flashcards-fe flashcards-be jslib-example \
    project-mrzli-archon project-mrzli-docs project-mrzli-js-templates project-mrzli-learning project-mrzli-mrzli-github-io project-mrzli-repos project-mrzli-skills
}

test_terminal_named_group() {
  create_fixtures || return
  run_terminal_archon workspaces start -g general || return
  assert_attachment main || return
  assert_sessions main
}

test_terminal_inside_tmux() {
  create_fixtures || return
  export TMUX=fake-client
  run_terminal_archon workspaces start -g general || return
  assert_sessions main || return
  assert_no_attachment
}

tests_run=0
tests_failed=0

run_test() {
  local name="$1"
  shift
  tests_run=$((tests_run + 1))

  if run_case "$@"; then
    printf 'PASS: %s\n' "$name"
  else
    printf 'FAIL: %s\n' "$name" >&2
    tests_failed=$((tests_failed + 1))
  fi
}

run_test 'named workspace group' test_named_group
run_test 'aggregate workspace groups' test_aggregate_groups
for prerequisite in script timeout; do
  if ! command -v "$prerequisite" >/dev/null 2>&1; then
    fail "terminal tests require $prerequisite"
    exit 1
  fi
done
run_test 'terminal aggregate attachment' test_terminal_aggregate
run_test 'terminal named-group attachment' test_terminal_named_group
run_test 'terminal inside tmux' test_terminal_inside_tmux

printf '%s tests, %s failures\n' "$tests_run" "$tests_failed"
[[ "$tests_failed" -eq 0 ]]
