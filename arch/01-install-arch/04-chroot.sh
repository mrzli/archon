#!/usr/bin/env bash

source ./shared.sh

USERNAME="$1"
USER_PASSWORD="$2"
DEVICE_PARTITION_EFI="$3"
DEVICE_PARTITION_ROOT="$4"
VOL_GROUP_NAME="$5"

echo "Starting chroot setup..."

echo ""

echo "Installing packages..."

echo ""

echo "Updating package database and upgrading all packages..."
pacman -Syu > /dev/null

echo ""

echo "Installing base packages, essential tools and applications..."
# Packages:
# - base-devel     - Collection of packages for building and compiling software.
# - dosfstools     - Tools for making and checking MS-DOS FAT filesystems.
# - mtools         - Tools for manipulating MS-DOS files.
# - grub           - Bootloader.
# - efibootmgr     - EFI boot manager.
# - sudo           - Allows users to run commands as root.
# - lvm2           - Logical volume management.
# - openssh        - SSH server and client
# - networkmanager - Network management service.
# - vim            - Text editor.
pacman_quiet_install \
  base-devel \
  dosfstools \
  mtools \
  grub \
  efibootmgr \
  sudo \
  lvm2 \
  openssh \
  networkmanager \
  vim 2> /dev/null || { echo "Failed to install base packages, essential tools and applications."; exit 1; }

echo ""

echo "Installing Linux kernel and headers..."
# Packages:
# - linux             - The Linux kernel.
# - linux-headers     - Header files and development tools for the current Linux kernel (optional, but needed if you will be building kernel modules).
# (optional)
# - linux-lts         - Long term support version of the Linux kernel.
# - linux-lts-headers - Header files and development tools for the current Linux LTS.
pacman_quiet_install \
  linux \
  linux-headers 2> /dev/null || { echo "Failed to install Linux kernel and headers."; exit 1; }

echo ""

echo "Installing drivers..."

# Packages:
# - linux-firmware - Proprietary binary firmware/drivers for various hardware devices.
# - nvidia         - NVidia kernel modules if you are using the latest kernel.
# - nvidia-utils   - NVidia driver libraries and utilities.
# (optional)
# - nvidia-lts     - NVidia kernel modules if you are using the LTS kernel.
pacman_quiet_install \
  linux-firmware \
  nvidia \
  nvidia-utils 2> /dev/null || { echo "Failed to install drivers."; exit 1; }

echo ""

HOSTNAME="$USERNAME-arch"

echo "Setting hostname..."
# TODO: for some reason does not seem to set hostname properly, at least I don't see it reflected in the prompt after installation.
hostnamectl set-hostname "$HOSTNAME" || { echo "Failed to set hostname."; exit 1; }

echo ""

echo "Configuring users..."

echo "Creating user '$USERNAME'..."
useradd -m -g users -G wheel "$USERNAME" || { echo "Failed to create user '$USERNAME'."; exit 1; }

echo "Setting password for users 'root' and '$USERNAME'..."
echo -e "root:$USER_PASSWORD\n$USERNAME:$USER_PASSWORD" | chpasswd || { echo "Failed to set passwords for users."; exit 1; }

echo "Configuring sudoers file to allow members of 'wheel' group to execute any command..."
sed -E -i 's/^# %wheel ALL=\(ALL:ALL\) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers \
  || { echo "Failed to configure sudoers file."; exit 1; }

echo ""

echo "Setting up system..."

echo "Setting default editor to vim..."
echo "EDITOR=/usr/bin/vim" >> /etc/environment || { echo "Failed to set EDITOR in /etc/environment."; exit 1; }

echo "Setting XDG base directories..."
cp ./data/xdg-sh /etc/profile.d/xdg.sh || { echo "Failed to copy xdg.sh to /etc/profile.d/."; exit 1; }

echo "Setting up locales..."
echo "Editing /etc/locale.gen..."
sed -E -i "s/^#\s*(en_US.UTF-8 UTF-8)/\1/" /etc/locale.gen \
  || { echo "Failed to edit /etc/locale.gen."; exit 1; }
echo "Generating locales..."
locale-gen > /dev/null || { echo "Failed to generate locales."; exit 1; }

echo ""

echo "Setting up RAM disk..."

echo "Editing /etc/mkinitcpio.conf to include 'encrypt' and 'lvm2' hooks..."
# Insert 'encrypt' and 'lvm2' before 'filesystems' in the HOOKS array, between 'block' and 'filesystems'.
# This is required for the system to know how to handle encrypted LVM partition during boot.
sed -E -i '/^HOOKS=/ { /encrypt lvm2/! s/(block)/\1 encrypt lvm2/ }' /etc/mkinitcpio.conf \
  || { echo "Failed to edit /etc/mkinitcpio.conf."; exit 1; }

echo "Regenerating the initramfs..."
mkinitcpio -p linux &> /dev/null || { echo "Failed to regenerate the initramfs."; exit 1; }
# mkinitcpio -p linux-lts &> /dev/null || { echo "Failed to regenerate the initramfs for LTS kernel."; exit 1; }

echo ""

echo "Setting up boot process..."

echo "Editing /etc/default/grub..."
# Add `cryptdevice=<device_partition_root>:<volume_group_name>` to the `GRUB_CMDLINE_LINUX_DEFAULT` line.
# Do not use '/' delimiter in 'sed' command to avoid conflicts with device paths.
sed -E -i \
  "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 cryptdevice=$DEVICE_PARTITION_ROOT:$VOL_GROUP_NAME quiet\"|" \
  /etc/default/grub \
  || { echo "Failed to edit /etc/default/grub."; exit 1; }

echo "Mounting EFI partition..."
mkdir -p /boot/EFI || { echo "Failed to create /boot/EFI directory."; exit 1; }
mount "$DEVICE_PARTITION_EFI" /boot/EFI > /dev/null \
  || { echo "Failed to mount EFI partition."; exit 1; }

echo "Installing GRUB bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=grub_uefi --recheck &> /dev/null \
  || { echo "Failed to install GRUB bootloader."; exit 1; }

echo "Copying GRUB's message catalog for English language..."
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo

echo "Generating GRUB configuration file..." 
grub-mkconfig -o /boot/grub/grub.cfg > /dev/null || { echo "Failed to generate GRUB configuration file."; exit 1; }

echo ""

echo "Enabling services to start on boot..."
systemctl enable \
  NetworkManager \
  sshd \
  &> /dev/null \
  || { echo "Failed to enable services."; exit 1; }
