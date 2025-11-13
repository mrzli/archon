import getpass
from .linux import get_block_device_names

def input_password(prompt):
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
