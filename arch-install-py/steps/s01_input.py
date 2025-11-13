import re
from util import get_block_device_names

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

username_regex = "^[a-z_][a-z0-9_-]{0,31}$"

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