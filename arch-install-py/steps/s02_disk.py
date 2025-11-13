import subprocess

def setup_disk(inputs):
    device_name = inputs.device_name

    print(f"Setting up disk '{device_name}'...\n\n")

    print(f"Wiping disk '{device_name}'...\n")
    clear_disk(inputs)
    subprocess.run(["wipefs", "-a", device_name], capture_output=True)

    # Create partitions.
    print(f"Creating new GPT partition table on '{device_name}'...\n")
    subprocess.run(f'echo "label: gpt" | sfdisk "{device_name}" ', shell=True)

    print(f"Creating 1GB EFI partition on '{device_name}'...\n")
    subprocess.run(f'echo "size=1GiB,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B" | sfdisk --append "{device_name}" ', shell=True)

    print(f"Creating LVM partition on the rest of space on '{device_name}'...\n")
    subprocess.run(f'echo "size=+,type=E6D6D379-F507-44C2-A23C-238F2A3DF928" | sfdisk --append "{device_name}" ', shell=True)

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

    