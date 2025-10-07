#!/usr/bin/env bash

phase_separator() {
  echo ""
  echo "----------------------------------------"
  echo ""
}

check_sigint() {
  if [ $? -eq 130 ]; then
    exit 130
  fi
}

pacman_quiet_install() {
  local pkg
  for pkg in "$@"; do
    if pacman -Q "$pkg" &>/dev/null && ! pacman -Qu "$pkg" &>/dev/null; then
      echo "$pkg is already installed and up to date."
    else
      pacman -S --noconfirm "$pkg" > /dev/null
      echo "$pkg installed."
    fi
  done
}
