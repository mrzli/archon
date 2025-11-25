import argparse
import os
from util import (
  command,
  LogLevel,
  Logger,
  LoggerConsoleHandler,
  LoggerFileHandler
)

log_dir = os.path.expanduser("~/.local/state/log")

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
    os.makedirs(log_dir, exist_ok=True)

    logger = Logger([
        LoggerConsoleHandler(LogLevel.INFO),
        LoggerFileHandler(LogLevel.DEBUG, os.path.join(log_dir, "archon-install.log"))
    ])

    logger.command(["clear"])
    command("export AAA=\"$HOME/.local/share/archon/bin:$PATH\" && echo $AAA", shell=True)
    command(["printenv"], output='all')
    logger.info("Welcome to the 'archon' Arch Linux setup tool.")

    print("Running install...")

def uninstall():
    os.makedirs(log_dir, exist_ok=True)

    print("Running uninstall...")

if __name__ == "__main__":
    setup()

