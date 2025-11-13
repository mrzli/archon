from util import command

def setup_chroot_prerequisites(inputs):
    print("Setup chroot prerequisites...\n")

    print("Installing essential packages...")
    essential_packages = [
        "base",
        "iptables-nft",
    ]
    command(["pacstrap", "/mnt", *essential_packages])

    print("Generating fstab file...")
    command(["genfstab -U /mnt >> /mnt/etc/fstab"], shell=True)

    print("\nFinished setting up chroot prerequisites.\n")
