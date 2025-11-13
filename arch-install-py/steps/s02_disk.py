import subprocess

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
    subprocess.run(["wipefs", "-a", device_name], capture_output=True, check=True)

    # Create partitions.
    print(f"Creating new GPT partition table on '{device_name}'...")
    subprocess.run(f'echo "label: gpt" | sfdisk "{device_name}" ', shell=True, capture_output=True, check=True)

    print(f"Creating 1GB EFI partition on '{device_name}'...")
    subprocess.run(f'echo "size=1GiB,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B" | sfdisk --append "{device_name}" ', shell=True, capture_output=True, check=True)

    print(f"Creating LVM partition on the rest of space on '{device_name}'...")
    subprocess.run(f'echo "size=+,type=E6D6D379-F507-44C2-A23C-238F2A3DF928" | sfdisk --append "{device_name}" ', shell=True, capture_output=True, check=True)

    # Set up root partition.
    print(f"Setting up LUKS encryption on root partition '{device_partition_root}'...")
    subprocess.run(f'echo {root_partition_password} | cryptsetup luksFormat --batch-mode "{device_partition_root}"', shell=True, capture_output=True, check=True)

    print(f"Opening LUKS encrypted root partition '{device_partition_root}' as '{lvm_name}'...")
    subprocess.run(f'echo {root_partition_password} | cryptsetup open --type luks "{device_partition_root}" "{lvm_name}"', shell=True, capture_output=True, check=True)

    print(f"Creating physical volume targetting '/dev/mapper/{lvm_name}'...")
    subprocess.run(["pvcreate", f"/dev/mapper/{lvm_name}"], capture_output=True, check=True)

    print(f"Creating volume group '{vol_group_name}' targetting '/dev/mapper/{lvm_name}'...")
    subprocess.run(["vgcreate", vol_group_name, f"/dev/mapper/{lvm_name}"], capture_output=True, check=True)

    print(f"Creating logical volume '{lv_name}' in volume group '{vol_group_name}' with all available space...")
    subprocess.run(["lvcreate", "-l", "100%VG", "-n", lv_name, vol_group_name], capture_output=True, check=True)

    print("Activating all volume groups...")
    subprocess.run(["vgchange", "-ay"], capture_output=True, check=True)

    # Format partitions.
    print(f"Formatting EFI partition '{device_partition_efi}' as FAT32...")
    subprocess.run(["mkfs.fat", "-F32", device_partition_efi], capture_output=True, check=True)
    root_lv = f"/dev/{vol_group_name}/{lv_name}"

    print(f"Formatting root logical volume '{root_lv}' as ext4...")
    subprocess.run(["mkfs.ext4", root_lv], capture_output=True, check=True)
    print("")

    # Mount partitions.
    print(f"Mounting root logical volume '{root_lv}' to '/mnt'...")
    subprocess.run(["mount", root_lv, "/mnt"], capture_output=True, check=True)

    print(f"Mounting EFI partition '{device_partition_efi}' to '/mnt/boot'...")
    subprocess.run(["mkdir", "-p", "/mnt/boot"], capture_output=True, check=True)
    subprocess.run(["mount", device_partition_efi, "/mnt/boot"], capture_output=True, check=True)
    print("\nDisk setup completed successfully.\n")


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

    