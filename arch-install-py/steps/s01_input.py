import re
from util import get_block_device_names, input_password

def process_installation_inputs():
    print("Collecting installation inputs...\n")

    inputs = get_installation_inputs()

    print("All inputs collected successfully.\n")

def get_installation_inputs():
    disk_name = choose_block_device()
    root_partition_password = input_password("Root partition password: ")
    username = input_username()
    user_password = input_password("User password: ")

    is_nvme = re.match(nvme_regex, disk_name)
    partition_suffix = "p" if is_nvme else ""
    device_name = f"/dev/{disk_name}"
    device_partition_efi = f"{device_name}{partition_suffix}1"
    device_partition_root = f"{device_name}{partition_suffix}2"

    # Arbitrary names for LVM setup.
    lvm_name = "lvm"
    vol_group_name = "volgroup0"
    lv_name = "lv_root"

    return {
        "disk_name": disk_name,
        "root_partition_password": root_partition_password,
        "username": username,
        "user_password": user_password,
        "device_name": device_name,
        "device_partition_efi": device_partition_efi,
        "device_partition_root": device_partition_root,
        "lvm_name": lvm_name,
        "vol_group_name": vol_group_name,
        "lv_name": lv_name,
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