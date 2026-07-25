#!/usr/bin/env bash

# Prerequisites.

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$XDG_CONFIG_HOME"

repo_root_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# Remove unneeded app and packages.

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

# Install packages.

omarchy-install-gaming-steam
omarchy-install-vscode

# Install AUR packages.
aur_packages_to_add=(
  postman-bin
)

for pkg in "${aur_packages_to_add[@]}"; do
  omarchy-pkg-aur-add "$pkg"
done

# Install regular packages.
packages_to_add=(
  tokei          # for counting lines of code in projects
  foliate        # ebook reader
  qbittorrent    # torrent client
  dbeaver        # database management tool

  # utilities
  img2pdf

  # for scanning documents
  sane 
  sane-airscan
  simple-scan
)

for pkg in "${packages_to_add[@]}"; do
  omarchy-pkg-add "$pkg"
done

# Install development tools.
dev_envs=(
  ruby
  python
  node
  bun
  zig
)

for env in "${dev_envs[@]}"; do
  omarchy-install-dev-env "$env"
done

# Install other mise tooling.

mise_tools=(
  pnpm
)

for tool in "${mise_tools[@]}"; do
  mise use --global "$tool"
done

# Install VSCode extensions.
vscode_extensions_file="$repo_root_dir/data/vscode-extensions.txt"
mapfile -t vscode_extensions < <(grep -Ev '^\s*(#|$)' "$vscode_extensions_file")

for extension in "${vscode_extensions[@]}"; do
  code --install-extension "$extension" --force
done

# Setup configs.

# Append custom content to ~/.bashrc
bashrc_file="$HOME/.bashrc"
bashrc_append_file="$repo_root_dir/data/home/bashrc-append.txt"
bashrc_marker="# Custom omarchy configuration"

if ! grep -q "^$bashrc_marker$" "$bashrc_file" 2>/dev/null; then
  echo -e "\n$bashrc_marker" >> "$bashrc_file"
  cat "$bashrc_append_file" >> "$bashrc_file"
fi

config_source_dir="$repo_root_dir/data/config"

for src in "$config_source_dir"/*; do
  [[ -d "$src" ]] || continue

  name="$(basename "$src")"
  rm -rf "$XDG_CONFIG_HOME/$name"
  cp -R "$src" "$XDG_CONFIG_HOME/$name"
done

# $XDG_CONFIG_HOME/hypr/hyprland.conf
# Read the file and meke sure it exists.
# Check whether it contains the following line:
#   source = ~/.config/hypr/hyprland-custom.conf
# If not, append it to the end of the file.
# Copy <repo_root>/data/hyprland-custom.conf to $XDG_CONFIG_HOME/hypr/hyprland-custom.conf.
hyprland_conf_file="$XDG_CONFIG_HOME/hypr/hyprland.conf"
if ! grep -q '^source = ~/.config/hypr/hyprland-custom.conf$' "$hyprland_conf_file"; then
  echo -e "\nsource = ~/.config/hypr/hyprland-custom.conf" >> "$hyprland_conf_file"
fi
cp "$repo_root_dir/data/hyprland-custom.conf" "$XDG_CONFIG_HOME/hypr/hyprland-custom.conf"

# Setup keyboard layouts.
keyboard_layouts=(
  us
  hr
)
keyboard_layouts_string="$(IFS=,; echo "${keyboard_layouts[*]}")"

hypr_input_file="$XDG_CONFIG_HOME/hypr/input.conf"
sed -i -E \
  -e '/^[[:space:]]*#?[[:space:]]*kb_(layout|options)[[:space:]]*=/d' \
  -e "/^input \\{/a\\  kb_layout = $keyboard_layouts_string\\n  kb_options = compose:caps,grp:alts_toggle" \
  "$hypr_input_file"

hyprctl reload
hyprctl configerrors

# Setup Waybar configuration.
waybar_config_file="$XDG_CONFIG_HOME/waybar/config.jsonc"
jq '
  .["hyprland/workspaces"]["persistent-workspaces"] = {"1": [], "2": [], "3": [], "4": [], "5": [], "6": [], "7": [], "8": [], "9": [], "10": []}
  | .["modules-right"] = ["group/tray-expander", "bluetooth", "network", "pulseaudio", "hyprland/language", "cpu", "battery"]
  | .["hyprland/language"] = {"format": "{short}"}
' "$waybar_config_file" > "$waybar_config_file.tmp" && mv "$waybar_config_file.tmp" "$waybar_config_file"

cat >> "$XDG_CONFIG_HOME/waybar/style.css" <<'EOF'

#language {
  padding: 0 4px 0 8px;
}
EOF

omarchy-restart-waybar
