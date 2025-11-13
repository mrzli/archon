import subprocess

def setup_disk(inputs):
    device_name = inputs.device_name

    print(f"Setting up disk '{device_name}'...\n\n")

    print(f"Wiping disk '{device_name}'...\n")
    clear_disk(inputs)
    subprocess.run(["wipefs", "-a", device_name], capture_output=True)

    # Create partitions.
    print(f"Creating new GPT partition table on '{device_name}'...\n")

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

    