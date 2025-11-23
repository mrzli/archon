import re
from types import SimpleNamespace
from util import (
    get_block_device_names,
    input_password,
    input_yes_no
)

def collect_inputs(logger):
    logger.info("Collecting installation inputs...")

    inputs = get_installation_inputs()

    logger.info("All inputs collected successfully.")

    return SimpleNamespace(**inputs)

def get_installation_inputs():
    input_values = get_user_input_values()
    # input_values = get_test_input_values()

    disk_name = input_values["disk_name"]
    root_partition_password = input_values["root_partition_password"]
    username = input_values["username"]
    user_password = input_values["user_password"]
    use_encryption = input_values["use_encryption"]
    use_lvm = input_values["use_lvm"]

    is_nvme = re.match(nvme_regex, disk_name)
    partition_suffix = "p" if is_nvme else ""
    device_name = f"/dev/{disk_name}"
    device_partition_efi = f"{device_name}{partition_suffix}1"
    device_partition_root = f"{device_name}{partition_suffix}2"

    # Arbitrary names for LVM setup.
    luks_mapping_name = "cryptroot"
    vol_group_name = "vg"
    lv_name = "rootlv"

    luks_mapping_path = f"/dev/mapper/{luks_mapping_name}"
    lv_path = f"/dev/{vol_group_name}/{lv_name}"

    root_partition_target = device_partition_root
    if use_lvm:
        root_partition_target = lv_path
    elif use_encryption:
        root_partition_target = luks_mapping_path

    pv_target = device_partition_root
    if use_encryption:
        pv_target = luks_mapping_path

    iana_tz_area = "Europe"
    iana_tz_location = "Zagreb"

    return {
        "disk_name": disk_name,
        "root_partition_password": root_partition_password,
        "username": username,
        "user_password": user_password,
        "use_encryption": use_encryption,
        "use_lvm": use_lvm,
        "device_name": device_name,
        "device_partition_efi": device_partition_efi,
        "device_partition_root": device_partition_root,
        "luks_mapping_name": luks_mapping_name,
        "vol_group_name": vol_group_name,
        "lv_name": lv_name,
        "luks_mapping_path": luks_mapping_path,
        "lv_path": lv_path,
        "root_partition_target": root_partition_target,
        "pv_target": pv_target,
        "iana_tz_area": iana_tz_area,
        "iana_tz_location": iana_tz_location,
    }

def get_user_input_values():
    return {
        "disk_name": choose_block_device(),
        "root_partition_password": input_password("Root partition password: "),
        "username": input_username(),
        "user_password": input_password("User password: "),
        "use_encryption": input_yes_no("Use disk encryption? (y/n): "),
        "use_lvm": input_yes_no("Use LVM? (y/n): "),
    }


def get_test_input_values():
    return {
        "disk_name": "nvme0n1",
        "root_partition_password": "pass",
        "username": "mrzli",
        "user_password": "pass",
        "use_encryption": True,
        "use_lvm": True,
    }

def choose_block_device():
    devices = get_block_device_names()
    if not devices:
        print("No disk devices found. Exiting.")
        exit(1)

    print("Available disks:")
    for i, name in enumerate(devices, 1):
        print(f"  {i}. {name}")

    while True:
        try:
            choice = int(input("Select disk number: ")) - 1

            if choice < 0 or choice >= len(devices):
                print("Invalid number. Please try again.")
                continue

            disk_name = devices[choice]
            return disk_name
        except ValueError:
            print("Please enter a valid number.")

def input_username():
    while True:
        username = input("Enter username: ").strip()

        if not username:
            print("Username cannot be empty. Please try again.")
            continue

        if not re.match(username_regex, username):
            print("Invalid username format. Please try again.")
            continue

        return username

username_regex = "^[a-z_][a-z0-9_-]{0,31}$"
nvme_regex = "^nvme[0-9]+n[0-9]+$"