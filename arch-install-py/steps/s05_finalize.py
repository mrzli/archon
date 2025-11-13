import sys
import subprocess
from util import command

def finalize_arch_installation(logger):
    logger.info("\nFinalizing setup...\n")

    # Prompt user for confirmation
    finish_choice = input("Setup complete. Unmount and reboot now? (y/n): ").strip()

    if finish_choice.lower() in ['y', 'yes']:
        logger.info("Unmounting all partitions...")
        try:
            command(['umount', '-a'])
        except subprocess.CalledProcessError:
            logger.warning("Warning: Unmount failed; some filesystems may still be mounted.")
        logger.info("Rebooting...")
        command(['reboot'])
    else:
        logger.info("Unmount and reboot canceled. Please remember to unmount all partitions and reboot manually later.")
