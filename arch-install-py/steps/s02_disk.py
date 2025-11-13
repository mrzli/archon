import subprocess

def setup_disk(inputs):
    device_name = inputs.device_name
    device_partition_efi = inputs.device_partition_efi
    device_partition_root = inputs.device_partition_root
    root_partition_password = inputs.root_partition_password
    lvm_name = inputs.lvm_name
    vol_group_name = inputs.vol_group_name
    lv_name = inputs.lv_name

    print(f"Setting up disk '{device_name}'...\n\n")

    print(f"Wiping disk '{device_name}'...\n")
    clear_disk(inputs)
    subprocess.run(["wipefs", "-a", device_name], capture_output=True)

    # Create partitions.
    print(f"Creating new GPT partition table on '{device_name}'...\n")
    subprocess.run(f'echo "label: gpt" | sfdisk "{device_name}" ', shell=True, capture_output=True)

    print(f"Creating 1GB EFI partition on '{device_name}'...\n")
    subprocess.run(f'echo "size=1GiB,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B" | sfdisk --append "{device_name}" ', shell=True, capture_output=True)

    print(f"Creating LVM partition on the rest of space on '{device_name}'...\n")
    subprocess.run(f'echo "size=+,type=E6D6D379-F507-44C2-A23C-238F2A3DF928" | sfdisk --append "{device_name}" ', shell=True, capture_output=True)

    # Set up root partition.

    # echo "Setting up LUKS encryption on root partition '$DEVICE_PARTITION_ROOT'..."
    # echo "$ROOT_PARTITION_PASSWORD" | cryptsetup luksFormat --batch-mode "$DEVICE_PARTITION_ROOT" > /dev/null || { echo "Failed to set up LUKS encryption on '$DEVICE_PARTITION_ROOT'."; exit 1; }

    # echo "Opening LUKS encrypted root partition '$DEVICE_PARTITION_ROOT' as '$LVM_NAME'..."
    # echo "$ROOT_PARTITION_PASSWORD" | cryptsetup open --type luks "$DEVICE_PARTITION_ROOT" "$LVM_NAME" > /dev/null || { echo "Failed to open LUKS encrypted partition '$DEVICE_PARTITION_ROOT'."; exit 1; }

    # echo "Creating physical volume targetting '/dev/mapper/$LVM_NAME'..."
    # pvcreate "/dev/mapper/$LVM_NAME" > /dev/null || { echo "Failed to create physical volume on '/dev/mapper/$LVM_NAME'."; exit 1; }

    # echo "Creating volume group '$VOL_GROUP_NAME' targetting '/dev/mapper/$LVM_NAME'..."
    # vgcreate "$VOL_GROUP_NAME" "/dev/mapper/$LVM_NAME" > /dev/null || { echo "Failed to create volume group '$VOL_GROUP_NAME'."; exit 1; }

    # echo "Creating logical volume '$LV_NAME' in volume group '$VOL_GROUP_NAME' with all available space..."
    # lvcreate -l 100%VG -n "$LV_NAME" "$VOL_GROUP_NAME" > /dev/null || { echo "Failed to create logical volume '$LV_NAME' in volume group '$VOL_GROUP_NAME'."; exit 1; }

    # echo "Activating all volume groups..."
    # vgchange -ay > /dev/null || { echo "Failed to activate volume groups."; exit 1; }

    # implement above comment in pyhron, ignore { echo "Failed to ..."; exit 1; } parts
    print(f"Setting up LUKS encryption on root partition '{device_partition_root}'...\n")
    subprocess.run(f'echo {root_partition_password} | cryptsetup luksFormat --batch-mode "{device_partition_root}"', shell=True, capture_output=True)

    print(f"Opening LUKS encrypted root partition '{device_partition_root}' as '{lvm_name}'...\n")
    subprocess.run(f'echo {root_partition_password} | cryptsetup open --type luks "{device_partition_root}" "{lvm_name}"', shell=True, capture_output=True)


def clear_disk(inputs):
    device_name = inputs.device_name
    vol_group_name = inputs.vol_group_name
    lv_name = inputs.lv_name

    root_lv = f"/dev/{vol_group_name}/{lv_name}"

    # Unmount all.
    subprocess.run(["umount", "/mnt/boot"], capture_output=True)
    subprocess.run(["umount", "/mnt"], capture_output=True)

    # Deactivate and remove the logical volume if it exists.
    subprocess.run(["lvchange", "-an", root_lv], capture_output=True)
    subprocess.run(["lvremove", "-f", root_lv], capture_output=True)

    # Deactivate and remove the volume group if it exists.
    subprocess.run(["vgchange", "-an", vol_group_name], capture_output=True)
    subprocess.run(["vgremove", "-f", vol_group_name], capture_output=True)

    # Remove the physical volume if it exists.
    subprocess.run(["pvremove", "-f", f"/dev/mapper/{lv_name}"], capture_output=True)

    # Close the LUKS mapping.
    subprocess.run(["cryptsetup", "close", lv_name], capture_output=True)

    