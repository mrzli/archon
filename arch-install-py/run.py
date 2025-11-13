#!/usr/bin/env python3

import getpass
import subprocess

disk_name = input("Disk name: ")
root_partition_password = getpass.getpass("Root partition password: ")
root_partition_password_confirm = getpass.getpass("Confirm password: ")

username = input("Username: ")
user_password = getpass.getpass("User password: ")
user_password_confirm = getpass.getpass("Confirm password: ")