#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: projects-status.sh

Checks every Git repository under:
  ~/projects/personal/<owner>/<repository>
USAGE
}

die() {
  echo "Error: $*" >&2
  exit 1
}

while (( $# > 0 )); do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      echo >&2
      die "Unknown argument: $1"
      ;;
  esac
  shift
done

command -v git >/dev/null 2>&1 ||
  die "Git is required but was not found."

home_dir="$(realpath -m -- "${HOME:?HOME is not set}")"
[[ "$home_dir" != "/" ]] ||
  die "Refusing to use the filesystem root as the home directory."

personal_projects_dir="$home_dir/projects/personal"

if [[ ! -d "$personal_projects_dir" ]]; then
  die "Personal projects directory not found: $personal_projects_dir"
fi

declare -a repository_paths=()
declare -a skipped_paths=()

shopt -s nullglob dotglob

for owner_dir in "$personal_projects_dir"/*; do
  [[ -d "$owner_dir" ]] || continue

  for repository_dir in "$owner_dir"/*; do
    [[ -d "$repository_dir" ]] || continue

    git_root=""
    if ! git_root="$(git -C "$repository_dir" rev-parse --show-toplevel 2>/dev/null)"; then
      skipped_paths+=("$repository_dir")
      continue
    fi

    repository_path="$(realpath -e -- "$repository_dir")"
    git_root="$(realpath -e -- "$git_root")"

    if [[ "$repository_path" != "$git_root" ]]; then
      skipped_paths+=("$repository_dir")
      continue
    fi

    repository_paths+=("$repository_dir")
  done
done

if (( ${#skipped_paths[@]} > 0 )); then
  echo "Entries that are not repository roots:"
  printf '  - %s\n' "${skipped_paths[@]}"
  echo
fi

if (( ${#repository_paths[@]} == 0 )); then
  echo "No repositories found under '$personal_projects_dir/<owner>/<repository>'."
  if (( ${#skipped_paths[@]} > 0 )); then
    exit 1
  else
    exit 0
  fi
fi

echo "Checking ${#repository_paths[@]} repositories..."
echo

ok_count=0
attention_count=0

for repository_dir in "${repository_paths[@]}"; do
  repository_name="${repository_dir#"$personal_projects_dir/"}"
  declare -a problems=()

  if ! git -C "$repository_dir" fetch --quiet; then
    problems+=("FETCH FAILED")
  fi

  status_output=""
  if ! status_output="$(git -C "$repository_dir" status --porcelain)"; then
    problems+=("STATUS FAILED")
  elif [[ -n "$status_output" ]]; then
    problems+=("UNCOMMITTED")
  fi

  branch=""
  if ! branch="$(git -C "$repository_dir" symbolic-ref --quiet --short HEAD)"; then
    problems+=("DETACHED HEAD")
  else
    upstream=""
    if ! upstream="$(git -C "$repository_dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)"; then
      problems+=("NO UPSTREAM")
    else
      counts=""
      if ! counts="$(git -C "$repository_dir" rev-list --left-right --count "$upstream...HEAD")"; then
        problems+=("COMPARISON FAILED")
      else
        read -r behind ahead <<< "$counts"

        if (( ahead > 0 && behind > 0 )); then
          problems+=("DIVERGED (ahead $ahead, behind $behind)")
        elif (( ahead > 0 )); then
          problems+=("UNPUSHED ($ahead commits)")
        elif (( behind > 0 )); then
          problems+=("BEHIND ($behind commits)")
        fi
      fi
    fi
  fi

  if (( ${#problems[@]} == 0 )); then
    echo "OK: $repository_name"
    (( ok_count += 1 ))
  else
    printf -v problem_text '%s; ' "${problems[@]}"
    problem_text="${problem_text%; }"
    echo "ATTENTION: $repository_name — $problem_text"
    (( attention_count += 1 ))
  fi
done

echo
printf 'Checked %d repositories: %d OK, %d need attention.\n' \
  "${#repository_paths[@]}" \
  "$ok_count" \
  "$attention_count"

if (( attention_count > 0 || ${#skipped_paths[@]} > 0 )); then
  exit 1
fi
