#!/usr/bin/env bash

echo "Finalizing setup..."

# Reboot, prompt user for confirmation.
read -p "Setup complete. Unmount and reboot now? (y/n): " FINISH_CHOICE
if [[ "$FINISH_CHOICE" =~ ^[Yy]$ ]]; then
  echo "Unmounting all partitions..."
  umount -a &> /dev/null
  echo "Rebooting..."
  reboot
else
  echo "Unmount and reboot canceled. Please remember to unmount all partitions and reboot manually later."
fi
