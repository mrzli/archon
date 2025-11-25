from util import command

def setup_disk(logger, inputs):
    device_name = inputs.device_name
    device_partition_efi = inputs.device_partition_efi
    device_partition_root = inputs.device_partition_root
    root_partition_password = inputs.root_partition_password
    luks_mapping_name = inputs.luks_mapping_name
    vol_group_name = inputs.vol_group_name
    lv_name = inputs.lv_name
    luks_mapping_path = inputs.luks_mapping_path
    lv_path = inputs.lv_path
    use_encryption = inputs.use_encryption
    use_lvm = inputs.use_lvm
    root_partition_target = inputs.root_partition_target
    pv_target = inputs.pv_target

    logger.info(f"Setting up disk '{device_name}'...")

    logger.info(f"Wiping disk '{device_name}'...")
    clear_disk(logger, inputs)
    logger.command(["wipefs", "-a", device_name])

    # Create partitions.
    partition_type_guid_efi = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
    partition_type_guid_linux_root = "4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709"
    partition_type_guid_linux_lvm = "E6D6D379-F507-44C2-A23C-238F2A3DF928"

    partition_type_guid_root = partition_type_guid_linux_lvm if use_lvm else partition_type_guid_linux_root

    logger.info(f"Creating new GPT partition table on '{device_name}'...")
    logger.command(f'echo "label: gpt" | sfdisk "{device_name}"', shell=True)

    logger.info(f"Creating 1GB EFI partition on '{device_name}'...")
    logger.command(f'echo "size=1GiB,type={partition_type_guid_efi}" | sfdisk --append "{device_name}"', shell=True)

    logger.info(f"Creating root partition on the rest of space on '{device_name}'...")
    logger.command(f'echo "size=+,type={partition_type_guid_root}" | sfdisk --append "{device_name}"', shell=True)

    # Set up root partition (LUKS + LVM).

    # Example commands for full LUKS + LVM setup:
    # cryptsetup luksFormat --batch-mode /dev/nvme0n1p2
    # cryptsetup open --type luks /dev/nvme0n1p2 cryptroot
    # pvcreate /dev/mapper/cryptroot
    # vgcreate vg /dev/mapper/cryptroot
    # lvcreate -l 100%VG -n rootlv vg
    # vgchange -ay

    if use_encryption:
        logger.info(f"Setting up LUKS encryption on root partition '{device_partition_root}'...")
        logger.command(f'echo {root_partition_password} | cryptsetup luksFormat --batch-mode "{device_partition_root}"', shell=True)

        logger.info(f"Opening LUKS encrypted root partition '{device_partition_root}' as '{luks_mapping_name}'...")
        logger.command(f'echo {root_partition_password} | cryptsetup open --type luks "{device_partition_root}" "{luks_mapping_name}"', shell=True)

    if use_lvm:
        logger.info(f"Make root partition '{pv_target}' into a physical volume...")
        logger.command(["pvcreate", pv_target])

        logger.info(f"Creating volume group '{vol_group_name}' targetting '{pv_target}'...")
        logger.command(["vgcreate", vol_group_name, pv_target])

        logger.info(f"Creating logical volume '{lv_name}' in volume group '{vol_group_name}' with all available space...")
        logger.command(["lvcreate", "-l", "100%VG", "-n", lv_name, vol_group_name])

        logger.info("Activating all volume groups...")
        logger.command(["vgchange", "-ay"])

    # Format partitions.
    logger.info(f"Formatting EFI partition '{device_partition_efi}' as FAT32...")
    logger.command(["mkfs.fat", "-F32", device_partition_efi])

    logger.info(f"Formatting root partition '{root_partition_target}' as ext4...")
    logger.command(["mkfs.ext4", root_partition_target])

    # Mount partitions.
    logger.info(f"Mounting root partition '{root_partition_target}' to '/mnt'...")
    logger.command(["mount", "-m", root_partition_target, "/mnt"])

    logger.info(f"Mounting EFI partition '{device_partition_efi}' to '/mnt/boot'...")
    logger.command(["mount", "-m", device_partition_efi, "/mnt/boot"])

    logger.info("Disk setup completed successfully.")

def clear_disk(logger, inputs):
    luks_mapping_name = inputs.luks_mapping_name
    vol_group_name = inputs.vol_group_name
    # lv_path = inputs.lv_path
    use_encryption = inputs.use_encryption
    use_lvm = inputs.use_lvm
    pv_target = inputs.pv_target

    # Unmount all.
    logger.command(["umount", "-R", "/mnt"], check=False)

    # Clean everything related to LVM and LUKS even if not using LVM and encryption now
    #  because they might be leftover from previous installation attempt.

    # if use_lvm:
    # # Deactivate and remove the logical volume if it exists.
    # logger.command(["lvchange", "-an", lv_path], check=False)
    # logger.command(["lvremove", "-f", lv_path], check=False)

    # Deactivate and remove the volume group if it exists.
    logger.command(["vgchange", "-an", vol_group_name], check=False)
    logger.command(["vgremove", "-f", vol_group_name], check=False)

    # Remove the physical volume if it exists.
    logger.command(["pvremove", "-f", pv_target], check=False)

    # if use_encryption:
    # Close the LUKS mapping.
    logger.command(["cryptsetup", "close", luks_mapping_name], check=False)