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

# Make scripts executable.
target_dir="$XDG_DATA_HOME/machine-setup"
find "$target_dir/scripts" -mindepth 1 -type f -exec chmod +x {} \;

# Copy repo install scripts to home directory for easy access.
install_script_dir="$HOME/ms"

rm -rf "$install_script_dir"
mkdir -p "$install_script_dir"

cp "$target_dir/scripts/install/"* "$install_script_dir/"
