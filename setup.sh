#!/usr/bin/env bash

# Prerequisites.

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$XDG_CONFIG_HOME"

repo_root_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# Remove unneeded app and packages.

packages_to_remove=(
  aether
  obsidian
)

omarchy pkg drop "${packages_to_remove[@]}"

webapps_to_remove=(
  Basecamp
  Fizzy
  HEY
)

for webapp in "${webapps_to_remove[@]}"; do
  omarchy webapp remove "$webapp"
done

# Install packages.

omarchy install gaming steam
omarchy install editor vscode

# Install AUR packages.
aur_packages_to_add=(
  postman-bin
)

omarchy pkg aur add "${aur_packages_to_add[@]}"

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

omarchy pkg add "${packages_to_add[@]}"

# Install development tools.
dev_envs=(
  ruby
  python
  node
  bun
  zig
)

for env in "${dev_envs[@]}"; do
  omarchy install dev-env "$env"
done

# Install other mise tooling.
mise_tools=(
  pnpm
)

mise use --global "${mise_tools[@]}"

# Install VSCode extensions.
vscode_extensions_file="$repo_root_dir/data/vscode-extensions.txt"
mapfile -t vscode_extensions < <(grep -Ev '^\s*(#|$)' "$vscode_extensions_file")

for extension in "${vscode_extensions[@]}"; do
  code --install-extension "$extension" --force
done

# Setup configs.

config_source_dir="$repo_root_dir/data/config"

for src in "$config_source_dir"/*; do
  [[ -d "$src" ]] || continue

  name="$(basename "$src")"
  mkdir -p "$XDG_CONFIG_HOME/$name"
  cp -R "$src"/. "$XDG_CONFIG_HOME/$name"/
done

# Load the managed shell configuration from ~/.bashrc.
bashrc_file="$HOME/.bashrc"
bashrc_source_line='source "${XDG_CONFIG_HOME:-$HOME/.config}/archon/bashrc"'

if ! grep -qFx "$bashrc_source_line" "$bashrc_file" 2>/dev/null; then
  printf '\n%s\n' "$bashrc_source_line" >> "$bashrc_file"
fi

hyprctl reload
hyprctl configerrors

# Delete ~/Projects directory if it exists.
rm -rf "$HOME/Projects"
