import sys
from util import (
    command,
    Logger,
    LoggerConsoleHandler,
    LoggerFileHandler,
    LogLevel
)

# Initialize logger.
logger = Logger([
    LoggerConsoleHandler(LogLevel.INFO),
    LoggerFileHandler(LogLevel.DEBUG, "/var/log/arch-install-py.log")
])

username = sys.argv[1]
user_password = sys.argv[2]
device_partition_efi = sys.argv[3]
device_partition_root = sys.argv[4]
vol_group_name = sys.argv[5]

logger.info("Starting chroot setup...")

logger.info("Installing packages...")

logger.info("Updating package database and upgrading system...")
logger.command(["pacman", "-Syu", "--noconfirm"])

logger.info("Installing base packages, essential tools and applications...")

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
logger.command(["pacman", "-S", "--noconfirm", *base_packages])

logger.info("Installing Linux kernel and headers...")

kernel_packages = [
    "linux",                 # The Linux kernel.
    "linux-headers",         # Header files and development tools for the current Linux kernel.
    # "linux-lts",           # Long term support version of the Linux kernel.
    # "linux-lts-headers",   # Header files and development tools for the current Linux LTS.
]
logger.command(["pacman", "-S", "--noconfirm", *kernel_packages])

logger.info("Installing drivers and firmware...")

# Create /etc/vconsole.conf to to avoid 'sd-vconsole' errors.
logger.command('echo -e "KEYMAP=us\nFONT=Lat2-Terminus16" > /etc/vconsole.conf', shell=True)

driver_packages = [
    "linux-firmware",   # Proprietary binary firmware/drivers for various hardware devices.
    "nvidia",           # NVidia kernel modules if you are using the latest kernel.
    "nvidia-utils",     # NVidia driver libraries and utilities.
    # "nvidia-lts",     # NVidia kernel modules if you are using the LTS kernel.
]
logger.command(["pacman", "-S", "--noconfirm", *driver_packages])

# hostname = f"{username}-arch"

# logger.info(f"Setting hostname to '{hostname}'...")
# logger.command(["hostnamectl", "set-hostname", hostname])

# logger.info("Configuring users...")

# logger.info(f"Creating user '{username}'...")
# logger.command(["useradd", "-m", "-g", "users", "-G", "wheel", username])
# logger.info(f"Setting password for users 'root' and '{username}'...")
# logger.command(f'echo -e "root:{user_password}\n{username}:{user_password}" | chpasswd', shell=True)
# logger.info("Configuring sudoers to allow members of 'wheel' group to execute any command...")
# logger.command(["sed", "-E", "-i", "s/^# %wheel ALL=\\(ALL:ALL\\) ALL/%wheel ALL=(ALL:ALL) ALL/", "/etc/sudoers"])

# logger.info("Setting up system...")

# logger.info("Setting default editor to vim...")
# logger.command('echo "EDITOR=/usr/bin/vim" >> /etc/environment', shell=True)

# logger.info("Setting XDG base directories...")
# logger.command(["cp", "./data/xdg-sh", "/etc/profile.d/xdg.sh"])

# logger.info("Setting up locales...")
# logger.info("Editing /etc/locale.gen...")
# logger.command(["sed", "-E", "-i", "s/^#\\s*(en_US.UTF-8 UTF-8)/\\1/", "/etc/locale.gen"])
# logger.info("Generating locales...")
# logger.command(["locale-gen"])

# logger.info("Setting up RAM disk...")

# # echo "Editing /etc/mkinitcpio.conf to include 'encrypt' and 'lvm2' hooks..."
# logger.info("Editing /etc/mkinitcpio.conf to include 'encrypt' and 'lvm2' hooks...")
# # Insert 'encrypt' and 'lvm2' before 'filesystems' in the HOOKS array, between 'block' and 'filesystems'.
# # This is required for the system to know how to handle encrypted LVM partition during boot.
# logger.command(["sed", "-E", "-i", r"/^HOOKS=/ { /encrypt lvm2/! s/(block)/\1 encrypt lvm2/ }", "/etc/mkinitcpio.conf"])

# # echo "Regenerating the initramfs..."
# logger.info("Regenerating the initramfs...")
# logger.command(["mkinitcpio", "-P"])

# logger.info("Setting up boot process...")

# logger.info("Editing /etc/default/grub...")

# # Add `cryptdevice=<device_partition_root>:<volume_group_name>` to the `GRUB_CMDLINE_LINUX_DEFAULT` line.
# # Do not use '/' delimiter in 'sed' command to avoid conflicts with device paths.
# logger.command([
#     "sed",
#     "-E",
#     "-i",
#     f"s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 cryptdevice={device_partition_root}:{vol_group_name} quiet\"|",
#     "/etc/default/grub"
# ])

# logger.info("Mounting EFI partition...")
# logger.command(["mkdir", "-p", "/boot/EFI"])
# logger.command(["mount", device_partition_efi, "/boot/EFI"])

# logger.info("Installing GRUB bootloader...")
# logger.command([
#     "grub-install",
#     "--target=x86_64-efi",
#     "--efi-directory=/boot/EFI",
#     "--bootloader-id=grub_uefi",
#     "--recheck"
# ])

# logger.info("Copying GRUB's message catalog for English language...")
# logger.command(["cp", "/usr/share/locale/en@quot/LC_MESSAGES/grub.mo", "/boot/grub/locale/en.mo"])

# logger.info("Generating GRUB configuration file...")
# logger.command(["grub-mkconfig", "-o", "/boot/grub/grub.cfg"])

# logger.info("Enabling services to start on boot...")

# services = [
#     "NetworkManager",   # Manages network connections.
#     "sshd"              # SSH server daemon.
# ]
# logger.command(["systemctl", "enable", *services])
