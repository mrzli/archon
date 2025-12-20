#!/usr/bin/env bash

# Prerequisites.

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$XDG_CONFIG_HOME"

# Remove unneeded.

packages_to_remove=(
	1password-beta
  1password-cli
  aether
  obsidian
  spotify
  typora
)

omarchy-pkg-drop "${packages_to_remove[@]}"

webapps_to_remove=(
  Basecamp
  Fizzy
  HEY
)

omarchy-webapp-remove "${webapps_to_remove[@]}"

# Install needed.

omarchy-install-steam
omarchy-install-vscode

# Install VSCode extensions.
vscode_extensions_file="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/data/vscode-extensions.txt"
mapfile -t vscode_extensions < <(grep -Ev '^\s*(#|$)' "$vscode_extensions_file")

for extension in "${vscode_extensions[@]}"; do
  code --install-extension "$extension" --force
done

# Setup configs.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
config_source_dir="$script_dir/data/config"

for src in "$config_source_dir"/*; do
  [[ -d "$src" ]] || continue

  name="$(basename "$src")"
  rm -rf "$XDG_CONFIG_HOME/$name"
  cp -R "$src" "$XDG_CONFIG_HOME/$name"
done

# $XDG_CONFIG_HOME/waybar/config.jsonc
# In the root object, replace "hyprland/workspaces"."persistent-workspaces" content with
# {
#   "1": [],
#   "2": [],
#   "3": [],
#   "4": [],
#   "5": [],
#   "6": [],
#   "7": [],
#   "8": [],
#   "9": [],
#   "10": []
# }
waybar_config_file="$XDG_CONFIG_HOME/waybar/config.jsonc"
jq '.["hyprland/workspaces"]["persistent-workspaces"] = {"1": [], "2": [], "3": [], "4": [], "5": [], "6": [], "7": [], "8": [], "9": [], "10": []}' "$waybar_config_file" > "$waybar_config_file.tmp" && mv "$waybar_config_file.tmp" "$waybar_config_file"

# Do this manually:
# - Log into Gmail and YouTube on Chromium.
# - Log into Grok.
