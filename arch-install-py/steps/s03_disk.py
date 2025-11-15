from util import command

def setup_disk(logger, inputs):
    device_name = inputs.device_name
    device_partition_efi = inputs.device_partition_efi
    device_partition_boot = inputs.device_partition_boot
    device_partition_root = inputs.device_partition_root
    root_partition_password = inputs.root_partition_password
    luks_mapping_name = inputs.luks_mapping_name
    vol_group_name = inputs.vol_group_name
    lv_name = inputs.lv_name
    luks_mapping_path = inputs.luks_mapping_path
    lv_path = inputs.lv_path

    logger.info(f"Setting up disk '{device_name}'...")

    logger.info(f"Wiping disk '{device_name}'...")
    clear_disk(logger, inputs)
    logger.command(["wipefs", "-a", device_name])

    # Create partitions.
    logger.info(f"Creating new GPT partition table on '{device_name}'...")
    logger.command(f'echo "label: gpt" | sfdisk "{device_name}"', shell=True)

    logger.info(f"Creating 1GB EFI partition on '{device_name}'...")
    logger.command(f'echo "size=1GiB,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B" | sfdisk --append "{device_name}"', shell=True)

    logger.info(f"Creating 1GB boot partition on '{device_name}'...")
    logger.command(f'echo "size=1GiB,type=BC13C2FF-59E6-4262-A352-B275FD6F7172" | sfdisk --append "{device_name}"', shell=True)

    logger.info(f"Creating LVM partition on the rest of space on '{device_name}'...")
    logger.command(f'echo "size=+,type=E6D6D379-F507-44C2-A23C-238F2A3DF928" | sfdisk --append "{device_name}"', shell=True)

    # Set up root partition.

    # Example commands:
    # cryptsetup luksFormat --batch-mode /dev/nvme0n1p3
    # cryptsetup open --type luks /dev/nvme0n1p3 root_crypt
    # pvcreate /dev/mapper/root_crypt
    # vgcreate volgroup0 /dev/mapper/root_crypt
    # lvcreate -l 100%VG -n lv_root volgroup0
    # vgchange -ay

    logger.info(f"Setting up LUKS encryption on root partition '{device_partition_root}'...")
    logger.command(f'echo {root_partition_password} | cryptsetup luksFormat --batch-mode "{device_partition_root}"', shell=True)

    logger.info(f"Opening LUKS encrypted root partition '{device_partition_root}' as '{luks_mapping_name}'...")
    logger.command(f'echo {root_partition_password} | cryptsetup open --type luks "{device_partition_root}" "{luks_mapping_name}"', shell=True)

    logger.info(f"Creating physical volume targetting '{luks_mapping_path}'...")
    logger.command(["pvcreate", luks_mapping_path])

    logger.info(f"Creating volume group '{vol_group_name}' targetting '{luks_mapping_path}'...")
    logger.command(["vgcreate", vol_group_name, luks_mapping_path])

    logger.info(f"Creating logical volume '{lv_name}' in volume group '{vol_group_name}' with all available space...")
    logger.command(["lvcreate", "-l", "100%VG", "-n", lv_name, vol_group_name])

    logger.info("Activating all volume groups...")
    logger.command(["vgchange", "-ay"])

    # Format partitions.
    logger.info(f"Formatting EFI partition '{device_partition_efi}' as FAT32...")
    logger.command(["mkfs.fat", "-F32", device_partition_efi])

    logger.info(f"Formatting boot partition '{device_partition_boot}' as ext4...")
    logger.command(["mkfs.ext4", device_partition_boot])

    logger.info(f"Formatting root logical volume '{lv_path}' as ext4...")
    logger.command(["mkfs.ext4", lv_path])

    # Mount partitions.
    logger.info(f"Mounting root logical volume '{lv_path}' to '/mnt'...")
    logger.command(["mount", "-m", lv_path, "/mnt"])

    logger.info(f"Mounting boot partition '{device_partition_boot}' to '/mnt/boot'...")
    logger.command(["mount", "-m", device_partition_boot, "/mnt/boot"])

    logger.info("Disk setup completed successfully.")

def clear_disk(logger, inputs):
    luks_mapping_name = inputs.luks_mapping_name
    vol_group_name = inputs.vol_group_name
    luks_mapping_path = inputs.luks_mapping_path
    lv_path = inputs.lv_path

    # Unmount all.
    logger.command(["umount", "-R", "/mnt"], check=False)

    # Deactivate and remove the logical volume if it exists.
    logger.command(["lvchange", "-an", lv_path], check=False)
    logger.command(["lvremove", "-f", lv_path], check=False)

    # Deactivate and remove the volume group if it exists.
    logger.command(["vgchange", "-an", vol_group_name], check=False)
    logger.command(["vgremove", "-f", vol_group_name], check=False)

    # Remove the physical volume if it exists.
    logger.command(["pvremove", "-f", luks_mapping_path], check=False)

    # Close the LUKS mapping.
    logger.command(["cryptsetup", "close", luks_mapping_name], check=False)
