#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: projects-update.sh [--dry-run]

Options:
  --dry-run  Discover and list repositories without pulling.
  -h, --help Show this help.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

dry_run=false

while (( $# > 0 )); do
  case "$1" in
    --dry-run)
      dry_run=true
      ;;
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
  echo "Skipping entries that are not repository roots:"
  printf '  - %s\n' "${skipped_paths[@]}"
  echo
fi

if (( ${#repository_paths[@]} == 0 )); then
  echo "No repositories found under '$personal_projects_dir/<owner>/<repository>'."
  exit 0
fi

if [[ "$dry_run" == "true" ]]; then
  echo "Repositories that would be updated (${#repository_paths[@]}):"
else
  echo "Repositories to update (${#repository_paths[@]}):"
fi

for repository_dir in "${repository_paths[@]}"; do
  printf '  - %s\n' "${repository_dir#"$personal_projects_dir/"}"
done

if [[ "$dry_run" == "true" ]]; then
  echo
  echo "Dry run complete. No repositories were updated."
  exit 0
fi

declare -a update_failures=()

for repository_dir in "${repository_paths[@]}"; do
  repository_name="${repository_dir#"$personal_projects_dir/"}"
  echo
  echo "Updating: $repository_name"

  if ! git -C "$repository_dir" pull --ff-only; then
    update_failures+=("$repository_name")
  fi
done

if (( ${#update_failures[@]} > 0 )); then
  echo >&2
  echo "Failed to update ${#update_failures[@]} repositories:" >&2
  printf '  - %s\n' "${update_failures[@]}" >&2
  exit 1
fi

echo
echo "Updated ${#repository_paths[@]} repositories."
