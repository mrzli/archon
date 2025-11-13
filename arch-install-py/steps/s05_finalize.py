import sys
import subprocess
from util import command

def finalize_arch_installation():
    print("\nFinalizing setup...\n")

    # Prompt user for confirmation
    finish_choice = input("Setup complete. Unmount and reboot now? (y/n): ").strip()

    if finish_choice.lower() in ['y', 'yes']:
        print("Unmounting all partitions...")
        try:
            command(['umount', '-a'])
        except subprocess.CalledProcessError:
            print("Warning: Unmount failed; some filesystems may still be mounted.")
        print("Rebooting...")
        command(['reboot'])
    else:
        print("Unmount and reboot canceled. Please remember to unmount all partitions and reboot manually later.")
