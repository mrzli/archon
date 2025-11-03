#!/usr/bin/env bash

set -e

REPO_URL="https://github.com/mrzli/machine-setup.git"

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

if ! type -P git &>/dev/null; then
  echo "Git not found. Installing git..."
  sudo pacman -Sy git --noconfirm
fi

mkdir -p "$XDG_DATA_HOME"

cd "$XDG_DATA_HOME"
git clone "$REPO_URL"

target_dir="$XDG_DATA_HOME/machine-setup"
find "$target_dir/path-scripts" -mindepth 1 -maxdepth 1 -type f -exec chmod +x {} \;
find "$target_dir/run" -mindepth 1 -maxdepth 1 -type f -exec chmod +x {} \;
find "$target_dir/run/scripts/" -mindepth 1 -maxdepth 1 -type f -exec chmod +x {} \;
