import sys
import shutil
from util import (
    command,
    get_block_device_uuid,
    Logger,
    LoggerConsoleHandler,
    LoggerFileHandler,
    LogLevel
)

# Initialize logger.
logger = Logger([
    LoggerConsoleHandler(LogLevel.INFO),
    LoggerFileHandler(LogLevel.DEBUG, "/var/log/arch-install.log")
])

cpu_vendor = sys.argv[1]
username = sys.argv[2]
user_password = sys.argv[3]
device_partition_efi = sys.argv[4]
device_partition_root = sys.argv[5]
luks_mapping_name = sys.argv[6]
use_encryption = sys.argv[7] == 'True'
use_lvm = sys.argv[8] == 'True'
iana_tz_area = sys.argv[9]
iana_tz_location = sys.argv[10]

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

    # Logical volume management.
    *(["lvm2"] if use_lvm else []),

    "openssh",          # SSH server and client.
    "networkmanager",   # Network management service.
    "vim",              # Text editor.
    "git"               # Version control system.
]
logger.command(["pacman", "-S", "--noconfirm", *base_packages])

logger.info("Installing Linux kernel and headers...")

# Create /etc/vconsole.conf to to avoid 'sd-vconsole' errors.
logger.command('echo "KEYMAP=us" > /etc/vconsole.conf', shell=True)

kernel_packages = [
    "linux",                 # The Linux kernel.
    "linux-headers",         # Header files and development tools for the current Linux kernel.
    # "linux-lts",           # Long term support version of the Linux kernel.
    # "linux-lts-headers",   # Header files and development tools for the current Linux LTS.
]
logger.command(["pacman", "-S", "--noconfirm", *kernel_packages])

logger.info("Installing drivers and firmware...")

driver_packages = [
    "linux-firmware",   # Proprietary binary firmware/drivers for various hardware devices.
    "nvidia",           # NVidia kernel modules if you are using the latest kernel.
    "nvidia-utils",     # NVidia driver libraries and utilities.
    # "nvidia-lts",     # NVidia kernel modules if you are using the LTS kernel.
]
logger.command(["pacman", "-S", "--noconfirm", *driver_packages])

hostname = f"{username}-arch"

logger.info(f"Setting hostname to '{hostname}'...")
# logger.command(["hostnamectl", "set-hostname", hostname])
# Directly write to /etc/hostname to avoid issues with hostnamectl in chroot not working for some reason.
logger.command(f'echo "{hostname}" > /etc/hostname', shell=True)

logger.info("Configuring users...")

logger.info(f"Creating user '{username}'...")
logger.command(["useradd", "-m", "-g", "users", "-G", "wheel", username])
logger.info(f"Setting password for users 'root' and '{username}'...")
logger.command(f'echo -e "root:{user_password}\n{username}:{user_password}" | chpasswd', shell=True)
logger.info("Configuring sudoers to allow members of 'wheel' group to execute any command...")
logger.command(["sed", "-E", "-i", "s/^# %wheel ALL=\\(ALL:ALL\\) ALL/%wheel ALL=(ALL:ALL) ALL/", "/etc/sudoers"])

logger.info("Setting up system...")

logger.info("Setting default editor to vim...")
logger.command('echo "EDITOR=/usr/bin/vim" >> /etc/environment', shell=True)

logger.info("Setting XDG base directories...")
python_project_dir = shutil.os.path.dirname(shutil.os.path.abspath(__file__))
logger.command(["cp", f"{python_project_dir}/data/xdg-sh", "/etc/profile.d/xdg.sh"])

logger.info("Setting up time...")
logger.info(f"Setting timezone to '{iana_tz_area}/{iana_tz_location}'...")
logger.command(["ln", "-sf", f"/usr/share/zoneinfo/{iana_tz_area}/{iana_tz_location}", "/etc/localtime"])
logger.info("Synchronizing hardware clock to system clock...")
logger.command(["hwclock", "--systohc"])

logger.info("Setting up locales...")
logger.info("Editing /etc/locale.gen...")
logger.command(["sed", "-E", "-i", "s/^#\\s*(en_US.UTF-8 UTF-8)/\\1/", "/etc/locale.gen"])
logger.info("Generating locales...")
logger.command(["locale-gen"])
logger.info("Setting LANG variable...")
logger.command('echo "LANG=en_US.UTF-8" > /etc/locale.conf', shell=True)

logger.info("Setting up RAM disk...")

if use_encryption or use_lvm:
    logger.info("Editing /etc/mkinitcpio.conf...")
    # Insert 'sd-encrypt' and 'lvm2' before 'filesystems' in the HOOKS array, between 'block' and 'filesystems', as necessary
    # This is required for the system to know how to handle encrypted LVM partition during boot.
    if use_encryption and use_lvm:
        logger.command(["sed", "-E", "-i", r"/^HOOKS=/ { /sd-encrypt lvm2/! s/(block)/\1 sd-encrypt lvm2/ }", "/etc/mkinitcpio.conf"])
    elif use_encryption:
        logger.command(["sed", "-E", "-i", r"/^HOOKS=/ { /sd-encrypt/! s/(block)/\1 sd-encrypt/ }", "/etc/mkinitcpio.conf"])
    elif use_lvm:
        logger.command(["sed", "-E", "-i", r"/^HOOKS=/ { /lvm2/! s/(block)/\1 lvm2/ }", "/etc/mkinitcpio.conf"])

    # echo "Regenerating the initramfs..."
    logger.info("Regenerating the initramfs...")
    logger.command(["mkinitcpio", "-P"])

logger.info("Setting up boot process...")

if use_encryption:
    logger.info("Editing /etc/default/grub...")
    # Add `cryptdevice=<device_partition_root>:<volume_group_name>` to the `GRUB_CMDLINE_LINUX_DEFAULT` line.
    # Do not use '/' delimiter in 'sed' command to avoid conflicts with device paths.
    root_device_uuid = get_block_device_uuid(device_partition_root)
    logger.command([
        "sed",
        "-E",
        "-i",
        f"s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet rd.luks.name={root_device_uuid}={luks_mapping_name}\"|",
        "/etc/default/grub"
    ])

logger.info("Installing GRUB bootloader...")
logger.command([
    "grub-install",
    "--target=x86_64-efi",
    "--efi-directory=/boot",
    "--bootloader-id=grub_uefi",
    "--recheck"
])

logger.info("Copying GRUB's message catalog for English language...")
logger.command(["cp", "/usr/share/locale/en@quot/LC_MESSAGES/grub.mo", "/boot/grub/locale/en.mo"])

logger.info("Generating GRUB configuration file...")
logger.command(["grub-mkconfig", "-o", "/boot/grub/grub.cfg"])

logger.info("Enabling services to start on boot...")

services = [
    "NetworkManager",   # Manages network connections.
    "sshd"              # SSH server daemon.
]
logger.command(["systemctl", "enable", *services])

logger.info("Chroot setup completed successfully.")
