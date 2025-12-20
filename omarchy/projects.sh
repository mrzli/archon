#!/usr/bin/env bash

set -euo pipefail

repo_root_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
projects_dir="$HOME/projects"

# Check if the projects directory exists. If it exists, delete, but prompt the user for confirmation.
if [[ -d "$projects_dir" ]]; then
  read -rp "The projects directory '$projects_dir' already exists. Do you want to delete it and recreate? (y/N): " confirm
  if [[ "$confirm" =~ ^[yY](es)?$ ]]; then
    rm -rf "$projects_dir"
  else
    echo "Aborting."
    exit 1
  fi
fi

mkdir -p "$projects_dir"

personal_projects_dir="$projects_dir/personal"

projects_data_dir="$repo_root_dir/omarchy/data/projects"

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

clone_repos() {
  local target_dir="$1"
  shift
  local repos=("$@")

  if [[ ${#repos[@]} -eq 0 ]]; then
    return 0
  fi

  for repo in "${repos[@]}"; do
    git clone "git@github.com:mrzli/$repo.git" "$target_dir/$repo"
  done
}

for subdir in "${personal_projects_subdirs[@]}"; do
  target_dir="$personal_projects_dir/$subdir"
  mkdir -p "$target_dir"

  projects_file="$projects_data_dir/${subdir//\//_}.txt"
  mapfile -t repos < <(read_project_file "$projects_file")

  clone_repos "$target_dir" "${repos[@]}"
done
