#!/usr/bin/env bash

usage() {
  echo "Usage:"
  echo "  ./ms.sh [command]"
  echo ""
  echo "Commands:"
  echo "  i - Install."
  echo "  d - Delete."
  echo "  c - Copy config."
}

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
target_dir="$XDG_DATA_HOME/machine-setup"

command="$1"

if [[ "$command" == "i" ]]; then
  curl -sSL https://raw.githubusercontent.com/mrzli/machine-setup/master/clone.sh | bash
  find "$target_dir/scripts" -mindepth 1 -maxdepth 1 -type f -exec chmod +x {} \;
  find "$target_dir/run" -mindepth 1 -maxdepth 1 -type f -exec chmod +x {} \;
  find "$target_dir/run/scripts/" -mindepth 1 -maxdepth 1 -type f -exec chmod +x {} \;
elif [[ "$command" == "d" ]]; then
  rm -rf "$target_dir"
elif [[ "$command" == "c" ]]; then
  "$target_dir/scripts/copy-config"
else
  usage
  exit 1
fi
