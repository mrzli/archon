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

if ! pacman -Q steam &>/dev/null; then
  omarchy install gaming steam
fi

if ! pacman -Q visual-studio-code-bin &>/dev/null; then
  omarchy install editor vscode
fi

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

declare -A dev_env_commands=(
  [ruby]=rails
  [python]=uv
  [node]=node
  [bun]=bun
  [zig]=zls
)

for dev_env in "${dev_envs[@]}"; do
  if ! command -v "${dev_env_commands[$dev_env]}" &>/dev/null; then
    omarchy install dev-env "$dev_env"
  fi
done

# Install other mise tooling.
mise_tools=(
  pnpm
)

for tool in "${mise_tools[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    mise use --global "$tool"
  fi
done

# Install VSCode extensions.
vscode_extensions_file="$repo_root_dir/data/vscode-extensions.txt"
mapfile -t vscode_extensions < <(grep -Ev '^\s*(#|$)' "$vscode_extensions_file")
installed_vscode_extensions="$(code --list-extensions)"

for extension in "${vscode_extensions[@]}"; do
  if ! grep -qiFx "$extension" <<< "$installed_vscode_extensions"; then
    code --install-extension "$extension"
  fi
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
