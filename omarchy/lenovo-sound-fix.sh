#!/usr/bin/env bash

set -euo pipefail

echo "Audio fix script starting..."

ORIGINAL_DIR="$(pwd)"
WORK_DIR="$HOME/kernel-audio-fix"
FIX_REPO_DIR="$WORK_DIR/fix-repo"
KERNEL_TAR="$WORK_DIR/linux-7.0.tar.xz"
KERNEL_DIR="$WORK_DIR/linux-7.0"
LOG_FILE="$WORK_DIR/build.log"

# echo "Installing necessary packages..."
# sudo pacman -Syu --needed --noconfirm base-devel git wget linux-headers nvidia-open-dkms dkms progress bc

# echo "Cleaning up any existing work directory..."
# rm -rf "$WORK_DIR"

# echo "Setting up work directory at $WORK_DIR..."
# mkdir -p "$WORK_DIR"

# echo "Cloning the audio fix repository..."
# git clone https://github.com/nadimkobeissi/16iax10h-linux-sound-saga.git "$FIX_REPO_DIR"

# echo "Installing AW88399 firmware..."
# sudo mkdir -p /lib/firmware
# sudo cp -f "$FIX_REPO_DIR/fix/firmware/aw88399_acf.bin" /lib/firmware/ 2>/dev/null || echo "Firmware copy skipped (already there or missing)"

# echo "Downloading Linux 7.0 sources..."
# wget -c -P "$WORK_DIR" https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.0.tar.xz

# echo "Extracting kernel sources..."
# tar -xJf "$KERNEL_TAR" -C "$WORK_DIR"

# echo "Copying patch..."
# cp "$FIX_REPO_DIR/fix/patches/16iax10h-audio-linux-7.0.patch" "$KERNEL_DIR/"

# echo "Applying patch..."
# ( cd "$KERNEL_DIR" && patch -p1 < 16iax10h-audio-linux-7.0.patch )
# echo "Patch applied (10 files should have been affected)"

# echo "Copying current kernel config..."
# zcat /proc/config.gz > "$KERNEL_DIR/.config"

# echo "Adding required audio options..."
# cat >> "$KERNEL_DIR/.config" << EOC

# # Audio fix for Legion Pro 7 16IAX10H
# CONFIG_SND_HDA_SCODEC_AW88399=m
# CONFIG_SND_HDA_SCODEC_AW88399_I2C=m
# CONFIG_SND_SOC_AW88399=m
# CONFIG_SND_SOC_SOF_INTEL_TOPLEVEL=y
# CONFIG_SND_SOC_SOF_INTEL_COMMON=m
# CONFIG_SND_SOC_SOF_INTEL_MTL=m
# CONFIG_SND_SOC_SOF_INTEL_LNL=m
# EOC

# echo "Config ready."

# echo "=== Starting kernel build ==="
# echo "Build log: $WORK_DIR/build.log"

# ORIGINAL_DIR="$(pwd)"
# cd "$KERNEL_DIR"

# echo "Cleaning previous build artifacts..."
# make clean || true

# echo "[Phase 1/3] Building kernel (this takes the longest)..."
# make -j24 2>&1 | tee "$WORK_DIR/build.log"

# echo "[Phase 2/3] Building modules..."
# make -j24 modules 2>&1 | tee -a "$WORK_DIR/build.log"

# echo "[Phase 3/3] Installing modules..."
# sudo make -j24 modules_install 2>&1 | tee -a "$WORK_DIR/build.log"

# echo "Build finished."

# cd "$ORIGINAL_DIR"
# echo "Restored to original directory: $(pwd)"

echo "Copying kernel to /boot..."
sudo cp -f "$WORK_DIR/linux-7.0/arch/x86/boot/bzImage" /boot/vmlinuz-linux-16iax10h-audio

echo "Creating mkinitcpio preset..."
sudo cp /etc/mkinitcpio.d/linux.preset /etc/mkinitcpio.d/linux-16iax10h-audio.preset


# ==================================================================
# ==================== MANUAL STEPS AFTER SCRIPT ===================
# ==================================================================
#
# 1. mkinitcpio preset:
#    sudo nvim /etc/mkinitcpio.d/linux-16iax10h-audio.preset
#
#    Content should be:
#    ALL_kver="/boot/vmlinuz-linux-16iax10h-audio"
#    PRESETS=('default')
#    default_image="/boot/initramfs-linux-16iax10h-audio.img"
#
# 2. Generate initramfs:
#    sudo mkinitcpio -p linux-16iax10h-audio
#    → Answer 'y' when asked about limine-mkinitcpio
#
# 3. Create Limine boot entry:
#    sudo mkdir -p /boot/loader/entries
#    sudo nvim /boot/loader/entries/linux-16iax10h-audio.conf
#
#    Content:
#    title   Arch Linux (16IAX10H Audio Fixed)
#    linux   /vmlinuz-linux-16iax10h-audio
#    initrd  /initramfs-linux-16iax10h-audio.img
#    options root=PARTUUID=45652f68-072c-48fd-86b0-45b18b5b4588 rw
#
# 4. Reboot:
#    reboot
#
# 5. At Limine menu, select:
#    → Arch Linux (16IAX10H Audio Fixed)
#
# 6. After boot, test audio:
#    speaker-test -c 2 -t sine -f 440
#    pavucontrol                  # boost volumes to 150-200%
#
# ==================================================================