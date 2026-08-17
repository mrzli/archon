#!/usr/bin/env bash

set -euo pipefail

log_step() {
  printf '\n==> %s\n' "$1"
}

log_info() {
  printf '    %s\n' "$1"
}

repo_root_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
home_source_dir="$repo_root_dir/data/home"

packages_to_remove=(
  aether
  obsidian
)

log_step "Removing unwanted packages"
omarchy pkg drop "${packages_to_remove[@]}"

webapps_to_remove=(
  Basecamp
  Fizzy
  HEY
)

log_step "Removing unwanted web apps"
for webapp in "${webapps_to_remove[@]}"; do
  omarchy webapp remove "$webapp"
done

log_step "Installing optional applications"
if pacman -Q steam &>/dev/null; then
  log_info "Steam is already installed; skipping"
else
  log_info "Installing Steam"
  omarchy install gaming steam
fi

if pacman -Q visual-studio-code-bin &>/dev/null; then
  log_info "VS Code is already installed; skipping"
else
  log_info "Installing VS Code"
  omarchy install editor vscode
fi

aur_packages=(
  postman-bin
)

log_step "Installing AUR packages"
omarchy pkg aur add "${aur_packages[@]}"

repository_packages=(
  tokei       # Count lines of code
  foliate     # Read ebooks
  qbittorrent # Download torrents
  dbeaver     # Manage databases

  # Utilities
  img2pdf

  # Document scanning
  sane
  sane-airscan
  simple-scan
)

log_step "Installing repository packages"
omarchy pkg add "${repository_packages[@]}"

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

log_step "Installing development environments"
for dev_env in "${dev_envs[@]}"; do
  if command -v "${dev_env_commands[$dev_env]}" &>/dev/null; then
    log_info "$dev_env is already installed; skipping"
  else
    log_info "Installing $dev_env"
    omarchy install dev-env "$dev_env"
  fi
done

mise_tools=(
  pnpm
)

log_step "Installing mise tools"
for mise_tool in "${mise_tools[@]}"; do
  if command -v "$mise_tool" &>/dev/null; then
    log_info "$mise_tool is already installed; skipping"
  else
    log_info "Installing $mise_tool"
    mise use --global "$mise_tool"
  fi
done

vscode_extensions_file="$repo_root_dir/data/vscode-extensions.txt"

log_step "Installing VS Code extensions"
mapfile -t vscode_extensions < <(grep -Ev '^[[:space:]]*(#|$)' "$vscode_extensions_file")
installed_vscode_extensions="$(code --list-extensions)"

for extension in "${vscode_extensions[@]}"; do
  if grep -qiFx "$extension" <<< "$installed_vscode_extensions"; then
    log_info "$extension is already installed; skipping"
  else
    log_info "Installing $extension"
    code --install-extension "$extension"
  fi
done

log_step "Installing home files"
cp -a "$home_source_dir"/. "$HOME"/

bashrc_file="$HOME/.bashrc"
bashrc_source_line='source "${XDG_CONFIG_HOME:-$HOME/.config}/archon/bashrc"'

if grep -qFx "$bashrc_source_line" "$bashrc_file" 2>/dev/null; then
  log_info "Bash configuration is already loaded; skipping"
else
  log_info "Adding managed Bash configuration to ~/.bashrc"
  printf '\n%s\n' "$bashrc_source_line" >> "$bashrc_file"
fi

log_step "Reloading Hyprland configuration"
hyprctl reload
hyprctl configerrors

log_step "Removing the default ~/Projects directory"
if [[ -e "$HOME/Projects" || -L "$HOME/Projects" ]]; then
  rm -rf "$HOME/Projects"
  log_info "Removed ~/Projects"
else
  log_info "~/Projects does not exist; skipping"
fi

printf '\nSetup complete. Open a new terminal or run: source ~/.bashrc\n'
