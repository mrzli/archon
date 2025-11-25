#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -eEo pipefail

export ARCHON_PATH="$HOME/.local/share/archon"
export PATH="$ARCHON_PATH/bin:$PATH"

archon-uninstall-paru