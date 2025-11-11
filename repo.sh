#!/usr/bin/env bash

ansi_art='
   ▄████████    ▄████████  ▄████████    ▄█    █▄     ▄██████▄  ███▄▄▄▄   
  ███    ███   ███    ███ ███    ███   ███    ███   ███    ███ ███▀▀▀██▄ 
  ███    ███   ███    ███ ███    █▀    ███    ███   ███    ███ ███   ███ 
  ███    ███  ▄███▄▄▄▄██▀ ███         ▄███▄▄▄▄███▄▄ ███    ███ ███   ███ 
▀███████████ ▀▀███▀▀▀▀▀   ███        ▀▀███▀▀▀▀███▀  ███    ███ ███   ███ 
  ███    ███ ▀███████████ ███    █▄    ███    ███   ███    ███ ███   ███ 
  ███    ███   ███    ███ ███    ███   ███    ███   ███    ███ ███   ███ 
  ███    █▀    ███    ███ ████████▀    ███    █▀     ▀██████▀   ▀█   █▀  
               ███    ███                                                '

clear
echo -e "\n$ansi_art\n"

sudo pacman -Syu --noconfirm --needed git

GIT_USER_NAME="mrzli"
GIT_REPO_NAME="archon"

FULL_REPO_NAME="$GIT_USER_NAME/$GIT_REPO_NAME"
FULL_REPO_URL="https://github.com/$FULL_REPO_NAME.git"

LOCAL_REPO_PATH="$HOME/.local/share/$GIT_REPO_NAME"

echo -e "\nCloning Archon from: $FULL_REPO_NAME..."
rm -rf "$LOCAL_REPO_PATH"
git clone "$FULL_REPO_URL" "$LOCAL_REPO_PATH"




set -e

REPO_NAME="archon"

REPO_URL="https://github.com/mrzli/$REPO_NAME.git"

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

if ! type -P git &>/dev/null; then
  echo "Git not found. Installing git..."
  sudo pacman -Sy git --noconfirm
fi

mkdir -p "$XDG_DATA_HOME"

cd "$XDG_DATA_HOME"
git clone "$REPO_URL"

# Make scripts executable.
target_dir="$XDG_DATA_HOME/archon"
find "$target_dir/scripts" -mindepth 1 -type f -exec chmod +x {} \;

# Copy repo install scripts to home directory for easy access.
install_script_dir="$HOME/ms"

rm -rf "$install_script_dir"
mkdir -p "$install_script_dir"

cp "$target_dir/scripts/install/"* "$install_script_dir/"
