#!/usr/bin/env python3

from util import input_password, get_block_device_names

def choose_block_device():
    devices = get_block_device_names()
    if not devices:
        print("No disk devices found. Exiting.")
        exit(1)

    print("Available disks:")
    for i, name in enumerate(devices, 1):
        print(f"  {i}. {name}")

    disk_name = None

    while True:
        try:
            choice = int(input("Select disk number: ")) - 1
            if 0 <= choice < len(devices):
                disk_name = devices[choice]
                break
            else:
                print("Invalid number. Please try again.")
        except ValueError:
            print("Please enter a valid number.")

    return disk_name

disk_name = choose_block_device()
root_partition_password = input_password("Root partition password: ")
username = input("Username: ")
user_password = input_password("User password: ")