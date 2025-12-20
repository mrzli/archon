#!/usr/bin/env bash

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

personal_projects_subdirs=(
  "docs/generic"
  "docs/development"
  "libs/shared"
  "libs/browser"
  "libs/node"
  "libs/development"
  "libs/test"
  "tools"
  "setup"
  "sites"
  "trading"
  "problems"
  "example"
)

for subdir in "${personal_projects_subdirs[@]}"; do
  mkdir -p "$personal_projects_dir/$subdir"
done
