#!/usr/bin/env bash

source ./shared.sh

# start - helper functions
prompt_password() {
  local prompt_message="$1"
  local password=""
  local password_confirm=""

  while true; do
    password=$(gum input --password --prompt "$prompt_message")
    check_sigint

    if [ -z "$password" ]; then
      echo "Password is required." >&2
      continue
    fi

    password_confirm=$(gum input --password --prompt "Confirm password: ")
    check_sigint

    if [ "$password" != "$password_confirm" ]; then
      echo "Passwords do not match. Please try again." >&2
      continue
    fi

    break
  done

  printf "%s" "$password"
}
# end - helper functions

PROMPT_COLOR="#04B575"

export GUM_INPUT_CURSOR_FOREGROUND="$PROMPT_COLOR"
export GUM_INPUT_PROMPT_FOREGROUND="$PROMPT_COLOR"
export GUM_CHOOSE_HEADER_FOREGROUND="$PROMPT_COLOR"

echo "Collecting setup inputs..."

echo ""

echo "Updating package database..."
pacman -Sy > /dev/null || { echo "Failed to update package database."; exit 1; }

pacman_quiet_install gum || { echo "Failed to install 'gum'."; exit 1; }

echo ""

# DISK_NAMES=$(lsblk -d -n -o NAME,TYPE | awk '$2 == "disk" {print $1}')
DISK_NAME=""
DEVICE=""
IS_NVME=0

while true; do
  # DISK_NAME=$(echo "$DISK_NAMES" | gum filter --prompt "Disk name: " --placeholder "(e.g. sda or nvme0n1)" --height 5 --limit 1)
  DISK_NAME=$(gum input --prompt "Disk name: " --placeholder "(e.g. sda or nvme0n1)")
  check_sigint

  if [ -z "$DISK_NAME" ]; then
    echo "Disk name is required."
    continue
  fi

  DEVICE="/dev/$DISK_NAME"

  if [ ! -b "$DEVICE" ]; then
    echo "Device '$DEVICE' does not exist. Please enter a valid disk name." 
    continue
  fi

  break;
done

echo "Selected disk: '$DISK_NAME'."

# Determine whether the disk is NVMe or SATA based on the name.
if [[ "$DISK_NAME" =~ ^nvme[0-9]+n[0-9]+$ ]]; then
  IS_NVME=1
else
  IS_NVME=0
fi

echo ""

# PARTITION_STYLE_OPTION=$(gum choose "auto" "p" "nop" --selected "auto" --header "Select partition style:")
# USE_P=""

# if [ "$PARTITION_STYLE_OPTION" == "p" ]; then
#   USE_P="p"
#   echo "Selected partition style 'p'."
# elif [ "$PARTITION_STYLE_OPTION" == "nop" ]; then
#   USE_P=""
#   echo "Selected partition style 'nop'."
# else
#   USE_P=$([ "$IS_NVME" -eq 1 ] && echo "p" || echo "")
#   ACTUAL_PARTITION_STYLE_OPTION=$([ "$IS_NVME" -eq 1 ] && echo "p" || echo "nop")
#   echo "Selected partition style 'auto', defaulting to '$ACTUAL_PARTITION_STYLE_OPTION'."
# fi

# echo ""

USE_P=$([ "$IS_NVME" -eq 1 ] && echo "p" || echo "")

DEVICE_PARTITION_EFI="${DEVICE}${USE_P}1"
DEVICE_PARTITION_BOOT="${DEVICE}${USE_P}2"
DEVICE_PARTITION_ROOT="${DEVICE}${USE_P}3"

# These are arbitrary names for LVM setup.
LVM_NAME="lvm"
VOL_GROUP_NAME="volgroup0"
LV_NAME="lv_root"

ROOT_PARTITION_PASSWORD=$(prompt_password "Root partition password: ")
echo "Root partition password set."

echo ""

USERNAME=""
USERNAME_REGEX="^[a-z_][a-z0-9_-]{0,31}$"

while true; do
  USERNAME=$(gum input --prompt "Username: " --placeholder "(e.g. myuser)")
  check_sigint

  if [ -z "$USERNAME" ]; then
    echo "Username is required." >&2
    continue
  fi

  if ! [[ "$USERNAME" =~ $USERNAME_REGEX ]]; then
    echo "Invalid username. It must start with a letter or underscore, followed by up to 31 letters, digits, underscores, or hyphens." >&2
    continue
  fi

  break
done

echo "Selected username: '$USERNAME'."

USER_PASSWORD=$(prompt_password "User password: ")
echo "Password set. It will be used for both '$USERNAME' and 'root' users."

echo ""

echo "All inputs collected successfully!"
