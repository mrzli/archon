#!/usr/bin/env python3

from util import input_password, get_block_device_names

devices = get_block_device_names()
print("Available block devices:")
for device in devices:
    print(f"- {device}")

disk_name = input("Disk name: ")
root_partition_password = input_password("Root partition password: ")
username = input("Username: ")
user_password = input_password("User password: ")