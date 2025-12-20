#!/usr/bin/env bash

set -euo pipefail

# Do this manually:
# - Log into Gmail and YouTube on Chromium.
# - Log into Grok.

# Remove unneeded.

packages_to_remove=(
	1password
  aether
  obsidian
  spotify
  typora
)

for pkg in "${packages_to_remove[@]}"; do
	omarchy-pkg-remove "$pkg"
done

omarchy-webapp-remove Basecamp Fizzy HEY

# Install needed.

omarchy-install-steam
