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

clone_repos() {
  local target_dir=$1
  shift
  local repos=("$@")
  for repo in "${repos[@]}"; do
    git clone "git@github.com:mrzli/$repo.git" "$target_dir/$repo"
  done
}

# docs/generic
docs_generic_projects=(
  "docs"
  "generic-docs"
  "gm-docs"
  "repos"
)

clone_repos "$personal_projects_dir/docs/generic" "${docs_generic_projects[@]}"

# docs/development
# No repos.

# libs/shared
libs_shared_projects=(
  "apply-function"
  "array-create"
  "array-sort"
  "array-transformers"
  "assert"
  "binary-search"
  "comparers"
  "compose-function"
  "data-container-util"
  "date-util"
  "generic-functions"
  "generic-types"
  "nullish-checks"
  "number-util"
  "type-checks"
  "value-generators"
  "value-transformers"
)

clone_repos "$personal_projects_dir/libs/shared" "${libs_shared_projects[@]}"

# libs/browser
libs_browser_projects=(
  "browser-storage"
)

clone_repos "$personal_projects_dir/libs/browser" "${libs_browser_projects[@]}"

# libs/node
libs_node_projects=(
  "crypto"
  "exec-observable"
  "file-system"
  "package-json"
  "path"
)

clone_repos "$personal_projects_dir/libs/node" "${libs_node_projects[@]}"

# libs/development
libs_development_projects=(
  "eslint-config"
)

clone_repos "$personal_projects_dir/libs/development" "${libs_development_projects[@]}"

# libs/test
libs_test_projects=(
  "test-util"
)

clone_repos "$personal_projects_dir/libs/test" "${libs_test_projects[@]}"

# tools
tools_projects=(
  "github-tools"
)

clone_repos "$personal_projects_dir/tools" "${tools_projects[@]}"

# setup
setup_projects=(
  "archon"
)

clone_repos "$personal_projects_dir/setup" "${setup_projects[@]}"
