#!/usr/bin/env bash

set -euo pipefail

# Internal setup boundary: repository root, destination home, replacement mode.
repo_root_dir="${1:?repository root is required}"
destination_home="${2:?destination home is required}"
delete_managed_home_dirs="${3:?replacement mode is required}"
if [[ "$delete_managed_home_dirs" != true && "$delete_managed_home_dirs" != false ]]; then
  printf 'Invalid replacement mode: %s\n' "$delete_managed_home_dirs" >&2
  exit 2
fi
if [[ "$(realpath -m -- "$destination_home")" == / ]]; then
  printf 'Refusing to install home files into /\n' >&2
  exit 1
fi
home_source_dir="$repo_root_dir/data/home"
archon_cli_source_dir="$repo_root_dir/components/archon-cli"

log_step() {
  printf '\n==> %s\n' "$1"
}

log_info() {
  printf '    %s\n' "$1"
}

# Optionally replace managed home directories.
if [[ "$delete_managed_home_dirs" == true ]]; then
  home_replace_directories_file="$repo_root_dir/data/home-replace-directories.txt"
  canonical_home_dir="$(realpath -m -- "$destination_home")"

  log_step "Removing managed home directories"
  while IFS= read -r relative_dir; do
    [[ -z "$relative_dir" || "$relative_dir" == \#* ]] && continue

    destination_dir="$destination_home/$relative_dir"
    canonical_destination_dir="$(realpath -m -- "$destination_dir")"
    if [[ "$canonical_destination_dir" != "$canonical_home_dir/"* ]]; then
      printf 'Invalid managed home directory: %s\n' "$relative_dir" >&2
      exit 1
    fi

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
rsync -a --exclude-from="$home_copy_ignore_file" "$home_source_dir"/ "$destination_home"/

# Install the Archon CLI from its repository component.
log_step "Installing Archon CLI"
mkdir -p "$destination_home/.local/bin" "$destination_home/.local/lib/archon"
rsync -a --exclude='*.md' "$archon_cli_source_dir/lib/archon"/ "$destination_home/.local/lib/archon"/
install -m 755 "$archon_cli_source_dir/bin/archon" "$destination_home/.local/bin/archon"
ln -sfn archon "$destination_home/.local/bin/arc"
