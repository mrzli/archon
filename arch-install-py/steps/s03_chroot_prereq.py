from util import command

def setup_chroot_prerequisites(logger, inputs):
    logger.info("Setup chroot prerequisites...")

    logger.info("Installing essential packages...")
    essential_packages = [
        "base",
        "iptables-nft",
    ]
    command(["pacstrap", "/mnt", *essential_packages])

    logger.info("Generating fstab file...")
    command(["genfstab -U /mnt >> /mnt/etc/fstab"], shell=True)

    logger.info("Finished setting up chroot prerequisites.")
