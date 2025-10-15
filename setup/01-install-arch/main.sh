#!/usr/bin/env bash

source ./shared.sh

echo ""

# Relevant variables set in 01-input.sh:
# - DEVICE
# - PARTITION_STYLE_OPTION
# - DEVICE_PARTITION_EFI
# - DEVICE_PARTITION_BOOT
# - DEVICE_PARTITION_ROOT
# - LVM_NAME
# - VOL_GROUP_NAME
# - LV_NAME
# - ROOT_PARTITION_PASSWORD
# - USERNAME
# - USER_PASSWORD
source ./01-input.sh || { echo "Failed to get user input."; exit 1; }

phase_separator

./02-disk.sh \
  "$DEVICE" \
  "$DEVICE_PARTITION_EFI" \
  "$DEVICE_PARTITION_BOOT" \
  "$DEVICE_PARTITION_ROOT" \
  "$LVM_NAME" \
  "$VOL_GROUP_NAME" \
  "$LV_NAME" \
  "$ROOT_PARTITION_PASSWORD" || { echo "Failed to set up disk."; exit 1; }

phase_separator

./03-pre-chroot.sh || { echo "Failed to perform pre-chroot setup."; exit 1; }

phase_separator

mkdir -p /mnt/setup-arch
cp -r ./shared.sh ./04-chroot.sh ./data /mnt/setup-arch/
CHROOT_COMMAND="cd /setup-arch && ./04-chroot.sh \"$USERNAME\" \"$USER_PASSWORD\" \"$DEVICE_PARTITION_EFI\" \"$DEVICE_PARTITION_ROOT\" \"$VOL_GROUP_NAME\""
arch-chroot /mnt /bin/bash -c "$CHROOT_COMMAND" || { echo "Failed to perform chroot setup."; exit 1; }
rm -rf /mnt/setup-arch

phase_separator

./05-finalize.sh || { echo "Failed to finalize setup."; exit 1; }

echo ""

echo "Done!"
