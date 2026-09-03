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

assert_file_lacks() {
  local file="$1"
  local unexpected="$2"

  if [ -e "$file" ] && grep -Fq -- "$unexpected" "$file"; then
    fail "$file unexpectedly contains: $unexpected"
  fi
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

test_misc_projects_start_and_stop() {
  new_case
  local root="$HOME/projects/personal"
  local projects=(mrzli/docs mrzli/repos mrzli/archon mrzli/js-templates)
  local project session directory expected_windows expected_commands

  for project in "${projects[@]}"; do
    mkdir -p "$root/$project"
  done

  "$launchers_dir/misc-projects.sh" start || fail "first miscellaneous-project start failed"
  "$launchers_dir/misc-projects.sh" start || fail "second miscellaneous-project start failed"

  for project in "${projects[@]}"; do
    directory="$root/$project"
    session="project-${project//\//-}"
    assert_session_exists "$session"
    assert_equals "$directory" "$(<"$TMW_TMUX_STATE/sessions/$session/root")"
    expected_windows="$(printf 'nvim\t%s\ncodex\t%s\nshell\t%s\n' "$directory" "$directory" "$directory")"
    assert_equals "$expected_windows" "$(<"$TMW_TMUX_STATE/sessions/$session/windows")"
    expected_commands="$(printf '%s:nvim\tnvim .\n%s:codex\tcodex resume --last\n' "$session" "$session")"
    assert_equals "$expected_commands" "$(<"$TMW_TMUX_STATE/sessions/$session/commands")"
    assert_equals nvim "$(<"$TMW_TMUX_STATE/sessions/$session/selected")"
  done

  "$launchers_dir/misc-projects.sh" stop || fail "first miscellaneous-project stop failed"
  "$launchers_dir/misc-projects.sh" stop || fail "second miscellaneous-project stop failed"
  for project in "${projects[@]}"; do
    assert_session_absent "project-${project//\//-}"
  done

  new_case
  root="$HOME/projects/personal"
  mkdir -p "$root/mrzli/docs" "$root/mrzli/archon" "$root/mrzli/js-templates"
  local output
  if ! output="$("$launchers_dir/misc-projects.sh" start 2>&1)"; then
    fail "miscellaneous-project start with a missing project failed: $output"
    return
  fi
  case "$output" in
    *"Skipping project-mrzli-repos: directory does not exist:"*) ;;
    *) fail "missing miscellaneous project was not reported" ;;
  esac
  assert_session_exists project-mrzli-docs
  assert_session_absent project-mrzli-repos
  assert_session_exists project-mrzli-archon
  assert_session_exists project-mrzli-js-templates
}

create_all_project_fixtures() {
  mkdir -p \
    "$HOME/projects/workspaces" \
    "$HOME/projects/personal/mrzli/flashcards-fe" \
    "$HOME/projects/personal/mrzli/flashcards-be" \
    "$HOME/projects/personal/mrzli-jslib/alpha/.git" \
    "$HOME/projects/personal/mrzli/docs" \
    "$HOME/projects/personal/mrzli/repos" \
    "$HOME/projects/personal/mrzli/archon" \
    "$HOME/projects/personal/mrzli/js-templates"
}

test_aggregate_start_and_stop() {
  new_case
  create_all_project_fixtures

  "$launchers_dir/all.sh" start || fail "first aggregate start failed"
  "$launchers_dir/all.sh" start || fail "second aggregate start failed"

  local session_count attach_count kill_order expected_kill_order
  session_count="$(find "$TMW_TMUX_STATE/sessions" -mindepth 1 -maxdepth 1 -type d | wc -l)"
  assert_equals 10 "$session_count"
  attach_count="$(grep -c ' attach-session -t workspaces$' "$TMW_TMUX_STATE/calls")"
  assert_equals 2 "$attach_count"
  assert_file_lacks "$TMW_TMUX_STATE/calls" " switch-client -t workspaces"

  "$launchers_dir/all.sh" stop || fail "first aggregate stop failed"
  "$launchers_dir/all.sh" stop || fail "second aggregate stop failed"
  session_count="$(find "$TMW_TMUX_STATE/sessions" -mindepth 1 -maxdepth 1 -type d | wc -l)"
  assert_equals 0 "$session_count"

  kill_order="$(sed -n 's/.* kill-session -t //p' "$TMW_TMUX_STATE/calls")"
  expected_kill_order="$(printf '%s\n' \
    project-mrzli-docs \
    project-mrzli-repos \
    project-mrzli-archon \
    project-mrzli-js-templates \
    jslib-alpha \
    flashcards-fe \
    flashcards-be \
    workspaces \
    projects \
    libs)"
  assert_equals "$expected_kill_order" "$kill_order"

  new_case
  create_all_project_fixtures
  export TMUX=fake-client
  "$launchers_dir/all.sh" start || fail "aggregate start inside tmux failed"
  assert_file_contains "$TMW_TMUX_STATE/calls" "$test_dir/bin/tmux switch-client -t workspaces"
  assert_file_lacks "$TMW_TMUX_STATE/calls" " attach-session -t workspaces"
  unset TMUX
}

create_aggregate_stub_fixture() {
  aggregate_dir="$case_root/aggregate"
  export TMW_CHILD_CALLS="$case_root/child-calls"
  mkdir -p "$aggregate_dir"
  cp "$launchers_dir/all.sh" "$aggregate_dir/all.sh"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'group="$(basename "$0" .sh)"' \
    'printf "%s %s\\n" "$group" "$1" >> "$TMW_CHILD_CALLS"' \
    '[ "${TMW_FAIL_GROUP:-}" != "$group" ]' \
    > "$aggregate_dir/group-stub.sh"
  chmod +x "$aggregate_dir/all.sh" "$aggregate_dir/group-stub.sh"

  local group
  for group in hubs flashcards jslibs misc-projects; do
    ln -s group-stub.sh "$aggregate_dir/$group.sh"
  done
}

test_aggregate_failure_propagation() {
  new_case
  create_aggregate_stub_fixture
  export TMW_FAIL_GROUP=flashcards

  local output calls
  if output="$(cd "$HOME" && "$aggregate_dir/all.sh" start 2>&1)"; then
    fail "aggregate start succeeded despite a child failure"
    return
  fi
  calls="$(<"$TMW_CHILD_CALLS")"
  assert_equals $'hubs start\nflashcards start\njslibs start\nmisc-projects start' "$calls"
  case "$output" in
    *"Failed to start tmux group: flashcards"*) ;;
    *) fail "aggregate start did not identify its failing child" ;;
  esac
  assert_file_lacks "$TMW_TMUX_STATE/calls" "attach-session"
  assert_file_lacks "$TMW_TMUX_STATE/calls" "switch-client"

  : > "$TMW_CHILD_CALLS"
  export TMW_FAIL_GROUP=jslibs
  if output="$(cd "$HOME" && "$aggregate_dir/all.sh" stop 2>&1)"; then
    fail "aggregate stop succeeded despite a child failure"
    return
  fi
  calls="$(<"$TMW_CHILD_CALLS")"
  assert_equals $'misc-projects stop\njslibs stop\nflashcards stop\nhubs stop' "$calls"
  case "$output" in
    *"Failed to stop tmux group: jslibs"*) ;;
    *) fail "aggregate stop did not identify its failing child" ;;
  esac
  unset TMW_FAIL_GROUP
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
run_test "miscellaneous projects start and stop" test_misc_projects_start_and_stop
run_test "aggregate start and stop" test_aggregate_start_and_stop
run_test "aggregate failure propagation" test_aggregate_failure_propagation

echo "$tests_run tests, $tests_failed failures"
[ "$tests_failed" -eq 0 ]
