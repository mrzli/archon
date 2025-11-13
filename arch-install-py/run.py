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

disk_name = input("Disk name: ")
root_partition_password = enter_password("Root partition password: ")
username = input("Username: ")
user_password = enter_password("User password: ")