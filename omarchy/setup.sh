#!/usr/bin/env bash

set -euo pipefail

# Do this manually:
# - Log into Gmail and YouTube on Chromium.
# - Log into Grok.

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
