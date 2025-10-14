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
