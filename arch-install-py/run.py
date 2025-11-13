#!/usr/bin/env python3

from util import choose_block_device, input_password

disk_name = choose_block_device()
root_partition_password = input_password("Root partition password: ")
username = input("Username: ")
user_password = input_password("User password: ")