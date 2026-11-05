#!/usr/bin/env bash

set -euo pipefail

# Run manually once on each machine to remove packages no longer in use.
# Packages that are not installed are skipped. All the others go in one pacman
# transaction, along with dependencies no other package requires, even if they
# add optional features to another package, and the saved configuration files
# of everything removed. If another package still requires one of them, pacman
# names it and removes nothing.
omarchy pkg drop rust kdenlive obs-studio signal-desktop xournalpp dotnet-runtime-9.0

printf 'Cleanup complete.\n'
