#!/usr/bin/env bash

# Prerequisites.

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$XDG_CONFIG_HOME"

repo_root_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"

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
vscode_extensions_file="$repo_root_dir/omarchy/data/vscode-extensions.txt"
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

# $XDG_CONFIG_HOME/hyprland/hyprland.conf
# Read the file and meke sure it exists.
# Check whether it contains the following line:
#   source = ~/.config/hypr/hyprland-custom.conf
# If not, append it to the end of the file.
# Copy <repo_root>/omarchy/data/hyprland-custom.conf to $XDG_CONFIG_HOME/hypr/hyprland-custom.conf.
hyprland_conf_file="$XDG_CONFIG_HOME/hyprland/hyprland.conf"
if ! grep -q '^source = ~/.config/hypr/hyprland-custom.conf$' "$hyprland_conf_file"; then
  echo -e "\nsource = ~/.config/hypr/hyprland-custom.conf" >> "$hyprland_conf_file"
fi
cp "$repo_root_dir/omarchy/data/hyprland-custom.conf" "$XDG_CONFIG_HOME/hypr/hyprland-custom.conf"

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

omarchy-restart-waybar

# Do this manually:
# - Log into Gmail and YouTube on Chromium.
# - Log into Grok.
