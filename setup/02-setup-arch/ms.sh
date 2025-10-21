#!/usr/bin/evn bash

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
  curl -sSL https://raw.githubusercontent.com/mrzli/machine-setup/master/clone.sh
  find "$target_dir/scripts" -type f -exec chmod +x {} \;
  find "$target_dir/run" -type f -exec chmod +x {} \;
  find "$target_dir/run/scripts/" -type f -exec +x {} \;
elif [[ "$command" == "d" ]]; then
  rm -rf "$target_dir"
elif [[ "$command" == "c" ]]; then
  "$target_dir/scripts/copy-config"
else
  usage
  exit 1
fi
