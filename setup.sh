#!/usr/bin/env bash

set -euo pipefail

# Output helpers.
log_step() {
  printf '\n==> %s\n' "$1"
}

log_info() {
  printf '    %s\n' "$1"
}

usage() {
  printf 'Usage: %s [OPTIONS]\n\n' "${0##*/}"
  printf 'Options:\n'
  printf '  %-31s %s\n' '-d, --delete-managed-home-dirs' 'Delete and recreate directories listed in data/home-replace-directories.txt'
  printf '  %-31s %s\n' '-h, --help' 'Show this help and exit'
  printf '\nBy default, existing home directories are preserved and data/home is copied as an overlay.\n'
}

# Parse command-line options.
delete_managed_home_dirs=false

while (($# > 0)); do
  case "$1" in
    -d | --delete-managed-home-dirs)
      delete_managed_home_dirs=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

# Resolve managed file locations.
repo_root_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
home_source_dir="$repo_root_dir/data/home"

# Remove unwanted packages.
packages_to_remove=(
  aether
  obsidian
)

log_step "Removing unwanted packages"
omarchy pkg drop "${packages_to_remove[@]}"

# Remove unwanted web apps.
webapps_to_remove=(
  Basecamp
  Fizzy
  HEY
)

log_step "Removing unwanted web apps"
for webapp in "${webapps_to_remove[@]}"; do
  omarchy webapp remove "$webapp"
done

# Install optional desktop applications.
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

# Install configured AUR packages.
aur_packages=(
  # package-name
)

if ((${#aur_packages[@]} > 0)); then
  log_step "Installing AUR packages"
  omarchy pkg aur add "${aur_packages[@]}"
fi

# Install repository packages.
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

# Install development environments.
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

# Install globally managed mise tools.
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

# Install configured VS Code extensions.
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

# Optionally replace managed home directories.
if [[ "$delete_managed_home_dirs" == true ]]; then
  home_replace_directories_file="$repo_root_dir/data/home-replace-directories.txt"

  log_step "Removing managed home directories"
  while IFS= read -r relative_dir; do
    [[ -z "$relative_dir" || "$relative_dir" == \#* ]] && continue

    if [[ "$relative_dir" == /* || "/$relative_dir/" == *"/../"* || "/$relative_dir/" == *"/./"* || ! -d "$home_source_dir/$relative_dir" ]]; then
      printf 'Invalid managed home directory: %s\n' "$relative_dir" >&2
      exit 1
    fi

    destination_dir="$HOME/$relative_dir"
    if [[ -e "$destination_dir" || -L "$destination_dir" ]]; then
      rm -rf -- "$destination_dir"
      log_info "Removed ~/$relative_dir"
    else
      log_info "~/$relative_dir does not exist; skipping"
    fi
  done < "$home_replace_directories_file"
fi

# Copy the managed home overlay.
log_step "Installing home files"
home_copy_ignore_file="$repo_root_dir/data/home-copy-ignore.txt"
rsync -a --exclude-from="$home_copy_ignore_file" "$home_source_dir"/ "$HOME"/

# Enable the LazyVim REST extra.
lazyvim_config_file="$HOME/.config/nvim/lazyvim.json"
lazyvim_rest_extra="lazyvim.plugins.extras.util.rest"

log_step "Enabling LazyVim REST extra"
mkdir -p "$(dirname "$lazyvim_config_file")"
if [[ ! -f "$lazyvim_config_file" ]]; then
  printf '{}\n' > "$lazyvim_config_file"
fi

if jq -e --arg extra "$lazyvim_rest_extra" '(.extras // []) | index($extra) != null' "$lazyvim_config_file" &>/dev/null; then
  log_info "LazyVim REST extra is already enabled; skipping"
else
  lazyvim_config_tmp_file="$(mktemp)"
  jq --arg extra "$lazyvim_rest_extra" '.extras = ((.extras // []) + [$extra])' "$lazyvim_config_file" > "$lazyvim_config_tmp_file"
  install -m 644 "$lazyvim_config_tmp_file" "$lazyvim_config_file"
  rm -f "$lazyvim_config_tmp_file"
  log_info "Enabled LazyVim REST extra"
fi

# Load the managed Bash configuration.
bashrc_file="$HOME/.bashrc"
bashrc_source_line='source "${XDG_CONFIG_HOME:-$HOME/.config}/archon/bashrc"'

if grep -qFx "$bashrc_source_line" "$bashrc_file" 2>/dev/null; then
  log_info "Bash configuration is already loaded; skipping"
else
  log_info "Adding managed Bash configuration to ~/.bashrc"
  printf '\n%s\n' "$bashrc_source_line" >> "$bashrc_file"
fi

# Apply and validate Hyprland configuration.
log_step "Reloading Hyprland configuration"
hyprctl reload
hyprctl configerrors

# Remove the default projects directory.
log_step "Removing the default ~/Projects directory"
if [[ -e "$HOME/Projects" || -L "$HOME/Projects" ]]; then
  rm -rf "$HOME/Projects"
  log_info "Removed ~/Projects"
else
  log_info "~/Projects does not exist; skipping"
fi

printf '\nSetup complete. Open a new terminal or run: source ~/.bashrc\n'
