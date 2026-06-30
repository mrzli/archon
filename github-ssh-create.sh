#!/usr/bin/env bash

ssh_key_file="$HOME/.ssh/id_ed25519_github"
ssh_config_file="$HOME/.ssh/config"

# Generate key.
ssh-keygen -t ed25519 -C "goran.mrzljak@gmail.com" -f "$ssh_key_file" -N ""

# Add to agent (once).
ssh-add "$ssh_key_file"

# Setup SSH config (once).
cat << EOF >> "$ssh_config_file"
Host github.com
  HostName github.com
  User git
  IdentityFile $ssh_key_file
  IdentitiesOnly yes
  AddKeysToAgent yes
EOF
chmod 600 "$ssh_config_file"

# Copy public key to clipboard.
cat "$ssh_key_file.pub" | wl-copy
