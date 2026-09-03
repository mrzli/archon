#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"
launchers_dir="$repo_root/data/home/projects/workspaces"
temporary_root="$(mktemp -d)"

cleanup() {
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT

export PATH="$test_dir/bin:$PATH"
unset TMUX

new_case() {
  case_root="$(mktemp -d "$temporary_root/case.XXXXXX")"
  export HOME="$case_root/home"
  export TMW_TMUX_STATE="$case_root/tmux"
  unset TMW_TMUX_FAIL_COMMAND
  mkdir -p "$HOME" "$TMW_TMUX_STATE"
}

fail() {
  echo "FAIL: $*" >&2
  return 1
}

assert_file_contains() {
  local file="$1"
  local expected="$2"

  grep -Fqx -- "$expected" "$file" || fail "$file does not contain: $expected"
}

assert_equals() {
  local expected="$1"
  local actual="$2"

  [ "$actual" = "$expected" ] || fail "expected '$expected', got '$actual'"
}

assert_session_exists() {
  [ -d "$TMW_TMUX_STATE/sessions/$1" ] || fail "missing session: $1"
}

assert_session_absent() {
  [ ! -e "$TMW_TMUX_STATE/sessions/$1" ] || fail "unexpected session: $1"
}

test_harness_is_isolated() {
  new_case
  local project="$HOME/project"
  mkdir -p "$project"

  tmux new-session -d -s harness -c "$project" -n shell
  tmux new-window -t harness -c "$project" -n extra
  tmux send-keys -t harness:extra 'safe command' Enter
  tmux select-window -t harness:extra

  assert_session_exists harness
  assert_equals "$project" "$(<"$TMW_TMUX_STATE/sessions/harness/root")"
  assert_file_contains "$TMW_TMUX_STATE/sessions/harness/windows" $'shell\t'"$project"
  assert_file_contains "$TMW_TMUX_STATE/sessions/harness/windows" $'extra\t'"$project"
  assert_file_contains "$TMW_TMUX_STATE/sessions/harness/commands" $'harness:extra\tsafe command'
  assert_equals extra "$(<"$TMW_TMUX_STATE/sessions/harness/selected")"
  assert_file_contains "$TMW_TMUX_STATE/calls" "$test_dir/bin/tmux new-session -d -s harness -c $project -n shell"
}

test_hubs_start_and_stop() {
  new_case
  mkdir -p "$HOME/projects/workspaces" "$HOME/projects/personal"

  local output
  if ! output="$("$launchers_dir/hubs.sh" start 2>&1)"; then
    fail "first hubs start failed: $output"
    return
  fi
  if ! "$launchers_dir/hubs.sh" start; then
    fail "second hubs start failed"
    return
  fi

  assert_session_exists workspaces
  assert_session_exists projects
  assert_session_absent libs
  assert_equals $'shell\t'"$HOME/projects/workspaces" "$(<"$TMW_TMUX_STATE/sessions/workspaces/windows")"
  assert_equals $'shell\t'"$HOME/projects/personal" "$(<"$TMW_TMUX_STATE/sessions/projects/windows")"
  case "$output" in
    *"Skipping libs: directory does not exist: $HOME/projects/personal/mrzli-jslib"*) ;;
    *) fail "missing hub root was not reported" ;;
  esac

  "$launchers_dir/hubs.sh" stop || fail "first hubs stop failed"
  "$launchers_dir/hubs.sh" stop || fail "second hubs stop failed"
  assert_session_absent workspaces
  assert_session_absent projects
  assert_session_absent libs
}

test_flashcards_start_and_stop() {
  new_case
  local frontend="$HOME/projects/personal/mrzli/flashcards-fe"
  local backend="$HOME/projects/personal/mrzli/flashcards-be"
  local session directory dev_command expected_windows expected_commands
  mkdir -p "$frontend" "$backend"

  "$launchers_dir/flashcards.sh" start || fail "first flashcards start failed"
  "$launchers_dir/flashcards.sh" start || fail "second flashcards start failed"

  for session in flashcards-fe flashcards-be; do
    if [ "$session" = flashcards-fe ]; then
      directory="$frontend"
      dev_command="bun run dev"
    else
      directory="$backend"
      dev_command="pnpm run dev"
    fi

    assert_session_exists "$session"
    assert_equals "$directory" "$(<"$TMW_TMUX_STATE/sessions/$session/root")"
    expected_windows="$(printf 'nvim\t%s\ncodex\t%s\ndev\t%s\nshell\t%s\n' "$directory" "$directory" "$directory" "$directory")"
    assert_equals "$expected_windows" "$(<"$TMW_TMUX_STATE/sessions/$session/windows")"
    expected_commands="$(printf '%s:nvim\tnvim .\n%s:codex\tcodex resume --last\n%s:dev\t%s\n' "$session" "$session" "$session" "$dev_command")"
    assert_equals "$expected_commands" "$(<"$TMW_TMUX_STATE/sessions/$session/commands")"
    assert_equals nvim "$(<"$TMW_TMUX_STATE/sessions/$session/selected")"
  done

  "$launchers_dir/flashcards.sh" stop || fail "first flashcards stop failed"
  "$launchers_dir/flashcards.sh" stop || fail "second flashcards stop failed"
  assert_session_absent flashcards-fe
  assert_session_absent flashcards-be

  new_case
  backend="$HOME/projects/personal/mrzli/flashcards-be"
  mkdir -p "$backend"
  local output
  if ! output="$("$launchers_dir/flashcards.sh" start 2>&1)"; then
    fail "flashcards start with missing frontend failed: $output"
    return
  fi
  case "$output" in
    *"Skipping flashcards-fe: directory does not exist:"*) ;;
    *) fail "missing flashcards project was not reported" ;;
  esac
  assert_session_absent flashcards-fe
  assert_session_exists flashcards-be
}

test_jslibs_start_and_stop() {
  new_case
  local root="$HOME/projects/personal/mrzli-jslib"
  local directory session expected_windows expected_commands
  mkdir -p "$root/alpha/.git" "$root/beta/.git" "$root/not-a-repository" "$root/nested/child/.git"

  "$launchers_dir/jslibs.sh" start || fail "first jslibs start failed"
  "$launchers_dir/jslibs.sh" start || fail "second jslibs start failed"

  for session in jslib-alpha jslib-beta; do
    directory="$root/${session#jslib-}/"
    assert_session_exists "$session"
    assert_equals "$directory" "$(<"$TMW_TMUX_STATE/sessions/$session/root")"
    expected_windows="$(printf 'nvim\t%s\ncodex\t%s\nshell\t%s\n' "$directory" "$directory" "$directory")"
    assert_equals "$expected_windows" "$(<"$TMW_TMUX_STATE/sessions/$session/windows")"
    expected_commands="$(printf '%s:nvim\tnvim .\n%s:codex\tcodex resume --last\n' "$session" "$session")"
    assert_equals "$expected_commands" "$(<"$TMW_TMUX_STATE/sessions/$session/commands")"
    assert_equals nvim "$(<"$TMW_TMUX_STATE/sessions/$session/selected")"
  done
  assert_session_absent jslib-not-a-repository
  assert_session_absent jslib-nested

  tmux new-session -d -s unrelated -c "$HOME" -n shell
  "$launchers_dir/jslibs.sh" stop || fail "jslibs stop with matching sessions failed"
  assert_session_absent jslib-alpha
  assert_session_absent jslib-beta
  assert_session_exists unrelated
  "$launchers_dir/jslibs.sh" stop || fail "jslibs stop with only a nonmatching session failed"
  tmux kill-session -t unrelated
  "$launchers_dir/jslibs.sh" stop || fail "jslibs stop without a tmux server failed"

  new_case
  local output
  if ! output="$("$launchers_dir/jslibs.sh" start 2>&1)"; then
    fail "jslibs start with missing root failed: $output"
    return
  fi
  case "$output" in
    *"Skipping JavaScript libraries: directory does not exist:"*) ;;
    *) fail "missing JavaScript-library root was not reported" ;;
  esac

  export TMW_TMUX_FAIL_COMMAND=list-sessions
  if "$launchers_dir/jslibs.sh" stop >/dev/null 2>&1; then
    fail "unexpected list-sessions failure was hidden"
  fi
  unset TMW_TMUX_FAIL_COMMAND
}

tests_run=0
tests_failed=0

run_test() {
  local name="$1"
  shift
  tests_run=$((tests_run + 1))

  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name" >&2
    tests_failed=$((tests_failed + 1))
  fi
}

run_test "isolated tmux harness" test_harness_is_isolated
run_test "hubs start and stop" test_hubs_start_and_stop
run_test "flashcards start and stop" test_flashcards_start_and_stop
run_test "JavaScript libraries start and stop" test_jslibs_start_and_stop

echo "$tests_run tests, $tests_failed failures"
[ "$tests_failed" -eq 0 ]
