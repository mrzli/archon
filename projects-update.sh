#!/usr/bin/env bash

set -euo pipefail

read_project_file() {
  local file_path="$1"
  [[ -f "$file_path" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading whitespace.
    line="${line#${line%%[![:space:]]*}}"

    [[ -n "$line" ]] || continue
    [[ "$line" == \#* ]] && continue

    printf '%s\n' "$line"
  done < "$file_path"
}

ensure_repo() {
  local target_dir="$1"
  local repo="$2"
  local repo_dir="$target_dir/$repo"
  local repo_url="git@github.com:mrzli/$repo.git"

  if [[ -e "$repo_dir" ]]; then
    if git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Updating: $repo_dir"
      git -C "$repo_dir" pull --ff-only
    else
      echo "Skipping (exists, not a git repo): $repo_dir"
    fi
    return 0
  fi

  echo "Cloning: $repo_url -> $repo_dir"
  git clone "$repo_url" "$repo_dir"
}

repo_root_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
projects_dir="$HOME/projects"
personal_projects_dir="$projects_dir/personal"
projects_data_dir="$repo_root_dir/omarchy/data/projects"

if [[ ! -d "$projects_data_dir" ]]; then
  echo "Projects data dir not found: $projects_data_dir"
  exit 1
fi

mkdir -p "$personal_projects_dir"

mapfile -t project_files < <(find "$projects_data_dir" -maxdepth 1 -type f -name '*.txt' -print | sort)

if [[ ${#project_files[@]} -eq 0 ]]; then
  echo "No project list files found in: $projects_data_dir"
  exit 1
fi

for projects_file in "${project_files[@]}"; do
  [[ -n "$projects_file" ]] || continue

  file_name="$(basename "$projects_file")"
  subdir_base="${file_name%.txt}"
  subdir="$(printf '%s' "$subdir_base" | tr '_' '/')"

  target_dir="$personal_projects_dir/$subdir"
  mkdir -p "$target_dir"

  mapfile -t repos < <(read_project_file "$projects_file")

  for repo in "${repos[@]}"; do
    ensure_repo "$target_dir" "$repo"
  done
done
