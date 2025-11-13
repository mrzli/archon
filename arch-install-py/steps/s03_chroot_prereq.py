from util import command

def setup_chroot_prerequisites(logger, inputs):
    logger.info("\nSetup chroot prerequisites...")

    logger.info("\nInstalling essential packages...")
    essential_packages = [
        "base",
        "iptables-nft",
    ]
    command(["pacstrap", "/mnt", *essential_packages])

    logger.info("Generating fstab file...")
    command(["genfstab -U /mnt >> /mnt/etc/fstab"], shell=True)

    logger.info("\nFinished setting up chroot prerequisites.\n")
