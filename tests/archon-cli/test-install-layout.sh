#!/usr/bin/env bash

set -u

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$test_dir/../.." && pwd)"
archon_cli_source="$repo_root/components/archon-cli"
bun "$archon_cli_source/scripts/build.mjs" || exit 1
home_source="$repo_root/data/home"
home_copy_ignore="$repo_root/data/home-copy-ignore.txt"
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

  rsync -a --exclude-from="$home_copy_ignore" "$home_source"/ "$home"/
}

copy_archon_cli() {
  local home="$1"

  mkdir -p "$home/.local"
  rsync -a "$archon_cli_source/dist"/ "$home/.local"/
}

install_home() {
  local home="$1"

  copy_home_overlay "$home"
  copy_archon_cli "$home"
}

test_type_errors_prevent_installation() {
  local component="$temporary_root/invalid-component"
  local destination="$temporary_root/failed-install"
  local error_file
  mkdir -p "$component"
  rsync -a --exclude=node_modules --exclude=dist "$archon_cli_source"/ "$component"/ || return
  ln -s "$archon_cli_source/node_modules" "$component/node_modules" || return

  for error_file in src/type-error.ts tests/type-error.test.ts; do
    printf '%s\n' 'const value: string = 123;' > "$component/$error_file"
    if bash -e -c '
      bun "$1/scripts/build.mjs"
      mkdir -p "$2"
      rsync -a "$1/dist"/ "$2"/
    ' bash "$component" "$destination" > "$temporary_root/type-error.log" 2>&1; then
      fail "type error in $error_file did not stop installation"
      return 1
    fi
    if ! grep -q 'TS2322' "$temporary_root/type-error.log"; then
      cat "$temporary_root/type-error.log" >&2
      fail 'build failed without the expected type error'
      return 1
    fi
    assert_absent "$destination" || return
    assert_absent "$component/dist" || return
    rm -f -- "$component/$error_file"
  done
}

test_repeated_build() {
  local first_manifest second_manifest unexpected_files archon_output alias_output
  first_manifest="$(cd "$archon_cli_source/dist" && find . -type f -exec sha256sum {} + | sort)"
  : > "$archon_cli_source/dist/stale-output.mjs"
  bun "$archon_cli_source/scripts/build.mjs" || return
  assert_absent "$archon_cli_source/dist/stale-output.mjs" || return
  second_manifest="$(cd "$archon_cli_source/dist" && find . -type f -exec sha256sum {} + | sort)"
  assert_equals "$first_manifest" "$second_manifest" || return
  unexpected_files="$(find "$archon_cli_source/dist" -type f ! -name '*.mjs' ! -name '*.js' ! -path '*/bin/archon')"
  assert_equals '' "$unexpected_files" || return
  [[ -L "$archon_cli_source/dist/bin/arc" ]] || fail 'built arc is not a symbolic link' || return
  assert_equals archon "$(readlink "$archon_cli_source/dist/bin/arc")" || return
  archon_output="$("$archon_cli_source/dist/bin/archon" --help)" || return
  alias_output="$("$archon_cli_source/dist/bin/arc" --help)" || return
  assert_equals "$archon_output" "$alias_output"
}

test_repeated_overlay_copy() {
  local home="$temporary_root/overlay-home"
  local archon_output alias_output tree_after_first tree_after_second
  mkdir -p "$home"

  mkdir -p "$home/.local/lib/archon/commands/workspaces/tests" "$home/.local/lib/unrelated"
  : > "$home/.local/lib/archon/commands/workspaces/tests/user-note.txt"
  : > "$home/.local/lib/unrelated/keep"

  install_home "$home"
  tree_after_first="$(find "$home" -printf '%P\t%y\t%l\n' | sort)"
  install_home "$home"
  tree_after_second="$(find "$home" -printf '%P\t%y\t%l\n' | sort)"

  assert_equals "$tree_after_first" "$tree_after_second" || return

  assert_exists "$home/.local/bin/archon" || return
  [[ -x "$home/.local/bin/archon" ]] || fail 'installed archon is not executable' || return
  [[ -L "$home/.local/bin/arc" ]] || fail 'installed arc is not a symbolic link' || return
  assert_equals archon "$(readlink "$home/.local/bin/arc")" || return

  archon_output="$(HOME="$home" "$home/.local/bin/archon" --help)" || return
  alias_output="$(HOME="$home" "$home/.local/bin/arc" --help)" || return
  assert_equals "$archon_output" "$alias_output" || return

  assert_absent "$home/.local/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/commands/libs/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/commands/libs/README.md" || return
  assert_absent "$home/.local/lib/archon/commands/projects/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/commands/projects/README.md" || return
  assert_absent "$home/.local/lib/archon/commands/workspaces/AGENTS.md" || return
  assert_absent "$home/.local/lib/archon/commands/workspaces/README.md" || return

  local source_test
  for source_test in "$archon_cli_source/tests/workspaces"/*; do
    assert_absent "$home/.local/lib/archon/commands/workspaces/tests/${source_test##*/}" || return
  done

  assert_exists "$home/.local/lib/archon/shared/arguments.js" || return
  assert_absent "$home/.local/lib/archon/shared/arguments.ts" || return
  assert_exists "$home/.local/lib/archon/cli.mjs" || return
  assert_exists "$home/.local/lib/archon/commands/libs/build.js" || return
  assert_exists "$home/.local/lib/archon/commands/libs/github-inventory.js" || return
  assert_exists "$home/.local/lib/archon/commands/libs/libs.js" || return
  assert_exists "$home/.local/lib/archon/commands/projects/github-inventory.js" || return
  assert_exists "$home/.local/lib/archon/commands/projects/projects.js" || return
  assert_exists "$home/.local/lib/archon/commands/workspaces/workspaces.js" || return
  assert_exists "$home/.local/lib/archon/commands/workspaces/tests/user-note.txt" || return
  assert_exists "$home/.local/lib/unrelated/keep"
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

run_test 'source and test type errors prevent installation' test_type_errors_prevent_installation
run_test 'repeat-safe JavaScript build' test_repeated_build
run_test 'repeated home-overlay copy' test_repeated_overlay_copy

printf '%s tests, %s failures\n' "$tests_run" "$tests_failed"
[[ "$tests_failed" -eq 0 ]]
