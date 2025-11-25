#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -eEo pipefail

export ARCHON_PATH="$HOME/.local/share/archon"
export PATH="$ARCHON_PATH/bin:$PATH"

sudo pacman -Syu --noconfirm

archon-install-paru
archon-install-packages-from-file "$ARCHON_PATH/setup/data/packages.txt"
