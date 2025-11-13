#!/usr/bin/env python3

from util import input_password
from steps import choose_block_device, input_username

disk_name = choose_block_device()
root_partition_password = input_password("Root partition password: ")
username = input_username()
user_password = input_password("User password: ")