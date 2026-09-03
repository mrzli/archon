#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"
archon="$repo_root/data/home/.local/bin/archon"
temporary_root="$(mktemp -d)"

cleanup() {
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT

export HOME="$temporary_root/home"
export PATH="$repo_root/tests/tmux-workspaces/bin:$PATH"
export TMW_TMUX_STATE="$temporary_root/tmux"
unset TMUX
mkdir -p "$HOME" "$TMW_TMUX_STATE"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

assert_session_exists() {
  [[ -d "$TMW_TMUX_STATE/sessions/$1" ]] || fail "missing session: $1"
}

assert_session_absent() {
  [[ ! -e "$TMW_TMUX_STATE/sessions/$1" ]] || fail "unexpected session: $1"
}

create_fixtures() {
  mkdir -p \
    "$HOME/projects/workspaces" \
    "$HOME/projects/personal/mrzli-jslib/example/.git" \
    "$HOME/projects/personal/mrzli/flashcards-fe" \
    "$HOME/projects/personal/mrzli/flashcards-be" \
    "$HOME/projects/personal/mrzli/docs" \
    "$HOME/projects/personal/mrzli/repos" \
    "$HOME/projects/personal/mrzli/archon" \
    "$HOME/projects/personal/mrzli/js-templates"
}

test_named_group_delegation() {
  create_fixtures

  "$archon" workspaces start --group flashcards || return
  assert_session_exists flashcards-fe || return
  assert_session_exists flashcards-be || return
  assert_session_absent workspaces || return

  "$archon" workspaces stop -g flashcards || return
  assert_session_absent flashcards-fe || return
  assert_session_absent flashcards-be
}

test_aggregate_delegation() {
  create_fixtures

  "$archon" workspaces start || return
  assert_session_exists workspaces || return
  assert_session_exists projects || return
  assert_session_exists libs || return
  assert_session_exists flashcards-fe || return
  assert_session_exists flashcards-be || return
  assert_session_exists jslib-example || return
  assert_session_exists project-mrzli-archon || return
  grep -Fqx -- "$repo_root/tests/tmux-workspaces/bin/tmux attach-session -t workspaces" "$TMW_TMUX_STATE/calls" ||
    fail 'aggregate start did not attach to workspaces' || return

  "$archon" workspaces stop || return
  assert_session_absent workspaces || return
  assert_session_absent projects || return
  assert_session_absent libs || return
  assert_session_absent flashcards-fe || return
  assert_session_absent flashcards-be || return
  assert_session_absent jslib-example || return
  assert_session_absent project-mrzli-archon
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

run_test 'named workspace delegation' test_named_group_delegation
run_test 'hybrid aggregate workspace delegation' test_aggregate_delegation

printf '%s tests, %s failures\n' "$tests_run" "$tests_failed"
[[ "$tests_failed" -eq 0 ]]
