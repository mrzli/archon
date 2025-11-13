import sys

print("Hello from chroot script")

username = sys.argv[1]
user_password = sys.argv[2]
device_partition_efi = sys.argv[3]
device_partition_root = sys.argv[4]
vol_group_name = sys.argv[5]

print("Username:", username)
print("User Password:", user_password)
print("Device Partition EFI:", device_partition_efi)
print("Device Partition Root:", device_partition_root)
print("Volume Group Name:", vol_group_name)
