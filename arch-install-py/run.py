#!/usr/bin/env python3

import getpass
import subprocess

def enter_password(prompt):
    while True:
        password = getpass.getpass(prompt)

        if not password:
            print("Password cannot be empty. Please try again.")
            continue

        password_confirm = getpass.getpass("Confirm password: ")
        if password != password_confirm:
            print("Passwords do not match. Please try again.")
            continue

        return password

import subprocess

def get_block_devices_detailed():
    try:
        result = subprocess.run(['lsblk', '-o', 'NAME', '-d', '-n'], 
                                capture_output=True, text=True, check=True)
        return result.stdout.strip().split('\n')[1:]  # Skip header
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"Error running lsblk: {e}")
        return []

# Example usage
for line in get_block_devices_detailed():
    print(line)

disk_name = input("Disk name: ")
root_partition_password = enter_password("Root partition password: ")
username = input("Username: ")
user_password = enter_password("User password: ")