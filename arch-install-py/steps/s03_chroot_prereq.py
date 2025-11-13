from util import command

def setup_chroot_prerequisites(inputs):
    print("\nSetup chroot prerequisites...\n")

    print("\nInstalling essential packages...")
    essential_packages = [
        "base",
        "iptables-nft",
    ]
    command(["pacstrap", "/mnt", *essential_packages])

    print("Generating fstab file...")
    command(["genfstab -U /mnt >> /mnt/etc/fstab"], shell=True)

    print("\nFinished setting up chroot prerequisites.\n")
