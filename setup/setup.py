import argparse

def setup():
    parser = argparse.ArgumentParser(description="Tool for installing or uninstalling 'archon' Arch Linux setup.")
    
    subparsers = parser.add_subparsers(dest="command", required=True)

    # "install" command (i or install)
    install_parser = subparsers.add_parser(
        'install',
        aliases=['i'],                  # ← allows "i" too
        help="Install 'archon' Arch Linux setup"
    )
    install_parser.set_defaults(func=install)

    # "uninstall" command (u or uninstall)
    uninstall_parser = subparsers.add_parser(
        'uninstall',
        aliases=['u'],                  # ← allows "u" too
        help="Uninstall 'archon' Arch Linux setup"
    )
    uninstall_parser.set_defaults(func=uninstall)

    args = parser.parse_args()
    args.func()  # calls install() or uninstall()

def install():
    print("Running install...")

def uninstall():
    print("Running uninstall...")

if __name__ == "__main__":
    setup()

