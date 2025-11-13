from util import command

def setup_disk(inputs):
    device_name = inputs.device_name
    device_partition_efi = inputs.device_partition_efi
    device_partition_root = inputs.device_partition_root
    root_partition_password = inputs.root_partition_password
    lvm_name = inputs.lvm_name
    vol_group_name = inputs.vol_group_name
    lv_name = inputs.lv_name

    print(f"Setting up disk '{device_name}'...\n")

    print(f"Wiping disk '{device_name}'...")
    clear_disk(inputs)
    command(["wipefs", "-a", device_name])

    # Create partitions.
    print(f"Creating new GPT partition table on '{device_name}'...")
    command(f'echo "label: gpt" | sfdisk "{device_name}"', shell=True)

    print(f"Creating 1GB EFI partition on '{device_name}'...")
    command(f'echo "size=1GiB,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B" | sfdisk --append "{device_name}"', shell=True)

    print(f"Creating LVM partition on the rest of space on '{device_name}'...")
    command(f'echo "size=+,type=E6D6D379-F507-44C2-A23C-238F2A3DF928" | sfdisk --append "{device_name}"', shell=True)

    # Set up root partition.
    print(f"Setting up LUKS encryption on root partition '{device_partition_root}'...")
    command(f'echo {root_partition_password} | cryptsetup luksFormat --batch-mode "{device_partition_root}"', shell=True)

    print(f"Opening LUKS encrypted root partition '{device_partition_root}' as '{lvm_name}'...")
    command(f'echo {root_partition_password} | cryptsetup open --type luks "{device_partition_root}" "{lvm_name}"', shell=True)

    print(f"Creating physical volume targetting '/dev/mapper/{lvm_name}'...")
    command(["pvcreate", f"/dev/mapper/{lvm_name}"])

    print(f"Creating volume group '{vol_group_name}' targetting '/dev/mapper/{lvm_name}'...")
    command(["vgcreate", vol_group_name, f"/dev/mapper/{lvm_name}"])

    print(f"Creating logical volume '{lv_name}' in volume group '{vol_group_name}' with all available space...")
    command(["lvcreate", "-l", "100%VG", "-n", lv_name, vol_group_name])

    print("Activating all volume groups...")
    command(["vgchange", "-ay"])

    # Format partitions.
    print(f"Formatting EFI partition '{device_partition_efi}' as FAT32...")
    command(["mkfs.fat", "-F32", device_partition_efi])

    root_lv = f"/dev/{vol_group_name}/{lv_name}"

    print(f"Formatting root logical volume '{root_lv}' as ext4...")
    command(["mkfs.ext4", root_lv])

    print("")

    # Mount partitions.
    print(f"Mounting root logical volume '{root_lv}' to '/mnt'...")
    command(["mount", root_lv, "/mnt"])

    print(f"Mounting EFI partition '{device_partition_efi}' to '/mnt/boot'...")
    command(["mkdir", "-p", "/mnt/boot"])
    command(["mount", device_partition_efi, "/mnt/boot"])

    print("\nDisk setup completed successfully.\n")


def clear_disk(inputs):
    device_name = inputs.device_name
    vol_group_name = inputs.vol_group_name
    lv_name = inputs.lv_name

    root_lv = f"/dev/{vol_group_name}/{lv_name}"

    # Unmount all.
    command(["umount", "-a", "-f"], check=False)
    # command(["umount", "/mnt/boot"])
    # command(["umount", "/mnt"])

    # Deactivate and remove the logical volume if it exists.
    command(["lvchange", "-an", root_lv], check=False)
    command(["lvremove", "-f", root_lv], check=False)

    # Deactivate and remove the volume group if it exists.
    command(["vgchange", "-an", vol_group_name], check=False)
    command(["vgremove", "-f", vol_group_name], check=False)

    # Remove the physical volume if it exists.
    command(["pvremove", "-f", f"/dev/mapper/{lv_name}"], check=False )

    # Close the LUKS mapping.
    command(["cryptsetup", "close", lv_name], check=False)

    