#!/usr/bin/env bash

echo "Pre-chroot setup..."

echo ""

echo "Installing essential packages..."
pacstrap /mnt \
  base \
  iptables-nft \
  &> /dev/null || { echo "Failed to install essential packages."; exit 1; }

echo "Generating fstab..."
genfstab -U -p /mnt >> /mnt/etc/fstab || { echo "Failed to generate fstab."; exit 1; }

echo ""

echo "Finished pre-chroot setup."
