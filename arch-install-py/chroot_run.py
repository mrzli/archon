import sys
from util import command

username = sys.argv[1]
user_password = sys.argv[2]
device_partition_efi = sys.argv[3]
device_partition_root = sys.argv[4]
vol_group_name = sys.argv[5]

print("Starting chroot setup...")

print("\nInstalling packages...")

print("\nUpdating package database and upgrading system...")
command(["pacman", "-Syu", "--noconfirm"])

print("\nInstalling base packages, essential tools and applications...")

base_packages = [
    "base-devel",       # Collection of packages for building and compiling software.
    "dosfstools",       # Tools for making and checking MS-DOS FAT filesystems.
    "mtools",           # Tools for manipulating MS-DOS files.
    "grub",             # Bootloader.
    "efibootmgr",       # EFI boot manager.
    "sudo",             # Allows users to run commands as root.
    "lvm2",             # Logical volume management.
    "openssh",          # SSH server and client.
    "networkmanager",   # Network management service.
    "vim",              # Text editor.
]
command(["pacman", "-S", "--noconfirm", *base_packages])

print("\nInstalling Linux kernel and headers...")

kernel_packages = [
    "linux",                 # The Linux kernel.
    "linux-headers",         # Header files and development tools for the current Linux kernel.
    # "linux-lts",           # Long term support version of the Linux kernel.
    # "linux-lts-headers",   # Header files and development tools for the current Linux LTS.
]
command(["pacman", "-S", "--noconfirm", *kernel_packages])

print("\nInstalling drivers and firmware...")

driver_packages = [
    "linux-firmware",   # Proprietary binary firmware/drivers for various hardware devices.
    "nvidia",           # NVidia kernel modules if you are using the latest kernel.
    "nvidia-utils",     # NVidia driver libraries and utilities.
    # "nvidia-lts",     # NVidia kernel modules if you are using the LTS kernel.
]
command(["pacman", "-S", "--noconfirm", *driver_packages])

hostname = f"{username}-arch"

print(f"\nSetting hostname to '{hostname}'...")
command(["hostnamectl", "set-hostname", hostname])

print("\nConfiguring users...")

print(f"Creating user '{username}'...")
command(["useradd", "-m", "-g", "users", "-G", "wheel", username])
print(f"Setting password for users 'root' and '{username}'...")
command(f'echo -e "root:{user_password}\n{username}:{user_password}" | chpasswd', shell=True)
print("Configuring sudoers to allow members of 'wheel' group to execute any command...")
command(["sed", "-E", "-i", "s/^# %wheel ALL=\\(ALL:ALL\\) ALL/%wheel ALL=(ALL:ALL) ALL/", "/etc/sudoers"])

# print("\nSetting up system...")

# print("Setting default editor to vim...")
# command('echo "EDITOR=/usr/bin/vim" >> /etc/environment', shell=True)

# print("Setting XDG base directories...")
# command(["cp", "./data/xdg-sh", "/etc/profile.d/xdg.sh"])

# print("Setting up locales...")
# print("Editing /etc/locale.gen...")
# command(["sed", "-E", "-i", "s/^#\\s*(en_US.UTF-8 UTF-8)/\\1/", "/etc/locale.gen"])
# print("Generating locales...")
# command(["locale-gen"])

# print("\nSetting up RAM disk...")

# # echo "Editing /etc/mkinitcpio.conf to include 'encrypt' and 'lvm2' hooks..."
# print("Editing /etc/mkinitcpio.conf to include 'encrypt' and 'lvm2' hooks...")
# # Insert 'encrypt' and 'lvm2' before 'filesystems' in the HOOKS array, between 'block' and 'filesystems'.
# # This is required for the system to know how to handle encrypted LVM partition during boot.
# command(["sed", "-E", "-i", r"/^HOOKS=/ { /encrypt lvm2/! s/(block)/\1 encrypt lvm2/ }", "/etc/mkinitcpio.conf"])

# # echo "Regenerating the initramfs..."
# print("Regenerating the initramfs...")
# command(["mkinitcpio", "-P"])

# print("\nSetting up boot process...")

# print("Editing /etc/default/grub...")

# # Add `cryptdevice=<device_partition_root>:<volume_group_name>` to the `GRUB_CMDLINE_LINUX_DEFAULT` line.
# # Do not use '/' delimiter in 'sed' command to avoid conflicts with device paths.
# command([
#     "sed",
#     "-E",
#     "-i",
#     f"s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 cryptdevice={device_partition_root}:{vol_group_name} quiet\"|",
#     "/etc/default/grub"
# ])

# print("Mounting EFI partition...")
# command(["mkdir", "-p", "/boot/EFI"])
# command(["mount", device_partition_efi, "/boot/EFI"])

# print("Installing GRUB bootloader...")
# command([
#     "grub-install",
#     "--target=x86_64-efi",
#     "--efi-directory=/boot/EFI",
#     "--bootloader-id=grub_uefi",
#     "--recheck"
# ])

# print("Copying GRUB's message catalog for English language...")
# command(["cp", "/usr/share/locale/en@quot/LC_MESSAGES/grub.mo", "/boot/grub/locale/en.mo"])

# print("Generating GRUB configuration file...")
# command(["grub-mkconfig", "-o", "/boot/grub/grub.cfg"])

# print("\nEnabling services to start on boot...")

# services = [
#     "NetworkManager",   # Manages network connections.
#     "sshd"              # SSH server daemon.
# ]
# command(["systemctl", "enable", *services])
