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

if ! type -P git &>/dev/null; then
  echo -e "\nGit not found. Installing git..."
  sudo pacman -Sy git --noconfirm
fi

git_username="mrzli"
repo_name="archon"

git_full_repo_name="$git_username/$repo_name"
git_full_repo_url="https://github.com/$git_full_repo_name.git"

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$XDG_DATA_HOME"

local_repo_path="$XDG_DATA_HOME/$repo_name"

echo -e "\nCloning Archon from: $git_full_repo_name..."
rm -rf "$local_repo_path"
git clone "$git_full_repo_url" "$local_repo_path" > /dev/null

echo -e "\nPost clone actions..."

echo -e "\nMaking scripts executable..."

# Make scripts executable.
find "$local_repo_path/bin" -mindepth 1 -type f -exec chmod +x {} \;
find "$local_repo_path/setup/setup" -mindepth 1 -type f -exec chmod +x {} \;

echo -e "\nDone.\n\n"
