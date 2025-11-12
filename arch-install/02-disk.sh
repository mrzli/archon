#!/usr/bin/env bash

# start - helper functions
clear_disk() {
  local device="$1"
  local lvm_name="$2"
  local vol_group_name="$3"
  local lv_name="$4"

  local root_lv="/dev/$vol_group_name/$lv_name"

  # Unmount all.
  umount /mnt/boot &> /dev/null || true
  umount /mnt &> /dev/null || true

  # Deactivate and remove the logical volume (if it exists).
  lvchange -an "$root_lv" &> /dev/null || true
  lvremove -f "$root_lv" &> /dev/null || true

  # Deactivate and remove the volume group.
  vgchange -an "$vol_group_name" &> /dev/null || true
  vgremove -f "$vol_group_name" &> /dev/null || true

  # Remove the physical volume.
  pvremove -f /dev/mapper/"$lvm_name" &> /dev/null || true

  # Close the LUKS mapping.
  cryptsetup close "$lvm_name" &> /dev/null || true
}
# end - helper functions

DEVICE="$1"
DEVICE_PARTITION_EFI="$2"
DEVICE_PARTITION_ROOT="$3"
LVM_NAME="$4"
VOL_GROUP_NAME="$5"
LV_NAME="$6"
ROOT_PARTITION_PASSWORD="$7"

echo "Setting up disk '$DEVICE'..."

echo ""

echo "Wiping disk '$DEVICE'..."
clear_disk "$DEVICE" "$LVM_NAME" "$VOL_GROUP_NAME" "$LV_NAME"
wipefs -a "$DEVICE" > /dev/null || { echo "Failed to wipe disk '$DEVICE'."; exit 1; }

# Create partitions.
echo "Creating new GPT partition table on '$DEVICE'..."
echo "label: gpt" | sfdisk "$DEVICE" > /dev/null || { echo "Failed to create GPT partition table on '$DEVICE'."; exit 1; }

echo "Creating 1GB EFI partition on '$DEVICE'..."
echo "size=1GiB,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B" | sfdisk --append "$DEVICE" &> /dev/null || { echo "Failed to create EFI partition on '$DEVICE'."; exit 1; }

echo "Creating LVM partition with the rest of the space on '$DEVICE'..."
echo "size=+,type=E6D6D379-F507-44C2-A23C-238F2A3DF928" | sfdisk --append "$DEVICE" &> /dev/null || { echo "Failed to create LVM partition on '$DEVICE'."; exit 1; }

# Set up root partition.
echo "Setting up LUKS encryption on root partition '$DEVICE_PARTITION_ROOT'..."
echo "$ROOT_PARTITION_PASSWORD" | cryptsetup luksFormat --batch-mode "$DEVICE_PARTITION_ROOT" > /dev/null || { echo "Failed to set up LUKS encryption on '$DEVICE_PARTITION_ROOT'."; exit 1; }

echo "Opening LUKS encrypted root partition '$DEVICE_PARTITION_ROOT' as '$LVM_NAME'..."
echo "$ROOT_PARTITION_PASSWORD" | cryptsetup open --type luks "$DEVICE_PARTITION_ROOT" "$LVM_NAME" > /dev/null || { echo "Failed to open LUKS encrypted partition '$DEVICE_PARTITION_ROOT'."; exit 1; }

echo "Creating physical volume targetting '/dev/mapper/$LVM_NAME'..."
pvcreate /dev/mapper/"$LVM_NAME" > /dev/null || { echo "Failed to create physical volume on '/dev/mapper/$LVM_NAME'."; exit 1; }

echo "Creating volume group '$VOL_GROUP_NAME' targetting '/dev/mapper/$LVM_NAME'..."
vgcreate "$VOL_GROUP_NAME" /dev/mapper/"$LVM_NAME" > /dev/null || { echo "Failed to create volume group '$VOL_GROUP_NAME'."; exit 1; }

echo "Creating logical volume '$LV_NAME' in volume group '$VOL_GROUP_NAME' with all available space..."
lvcreate -l 100%VG -n "$LV_NAME" "$VOL_GROUP_NAME" > /dev/null || { echo "Failed to create logical volume '$LV_NAME' in volume group '$VOL_GROUP_NAME'."; exit 1; }

echo "Activating all volume groups..."
vgchange -ay > /dev/null || { echo "Failed to activate volume groups."; exit 1; }

# Format partitions.
echo "Formatting EFI partition on '$DEVICE_PARTITION_EFI' as FAT32..."
mkfs.fat -F32 "$DEVICE_PARTITION_EFI" &> /dev/null || { echo "Failed to format EFI partition on '$DEVICE_PARTITION_EFI'."; exit 1; }

ROOT_LV="/dev/$VOL_GROUP_NAME/$LV_NAME"

echo "Formatting the root logical volume '$ROOT_LV' as ext4..."
mkfs.ext4 "$ROOT_LV" &> /dev/null || { echo "Failed to format the root logical volume '$ROOT_LV'."; exit 1; }

echo ""

# Mount partitions.
echo "Mounting root logical volume '$ROOT_LV' to '/mnt'..."
mount "$ROOT_LV" /mnt || { echo "Failed to mount root logical volume '$ROOT_LV' to '/mnt'."; exit 1; }

echo ""

echo "Disk setup complete!"
