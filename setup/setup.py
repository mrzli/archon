import argparse
from pathlib import Path
import os
import subprocess
from util import (
  command,
  LogLevel,
  Logger,
  LoggerConsoleHandler,
  LoggerFileHandler
)
from setup import install, uninstall

log_dir = os.path.expanduser("~/.local/state/log")

def setup():
    setup_rerequisites()

    parser = argparse.ArgumentParser(description="Tool for installing or uninstalling 'archon' Arch Linux setup.")
    
    subparsers = parser.add_subparsers(dest="command", required=True)

    # "install" command (i or install).
    install_parser = subparsers.add_parser(
        'install',
        aliases=['i'],
        help="Install 'archon' Arch Linux setup"
    )
    install_parser.set_defaults(func=install_wrapper)

    # "uninstall" command (u or uninstall).
    uninstall_parser = subparsers.add_parser(
        'uninstall',
        aliases=['u'],
        help="Uninstall 'archon' Arch Linux setup"
    )
    uninstall_parser.set_defaults(func=uninstall_wrapper)

    args = parser.parse_args()
    args.func()

def setup_rerequisites():
    os.makedirs(log_dir, exist_ok=True)

    archon_path = Path.home() / ".local/share/archon"
    archon_path.mkdir(parents=True, exist_ok=True)
    os.environ["ARCHON_PATH"] = str(archon_path)
    os.environ["PATH"] = str(archon_path / "bin") + os.pathsep + os.environ.get("PATH", "")

def install_wrapper():
    # logger = Logger([
    #     LoggerConsoleHandler(LogLevel.INFO),
    #     LoggerFileHandler(LogLevel.DEBUG, os.path.join(log_dir, "archon-install.log"))
    # ])

    # # logger.command(["clear"])
    # # command("export AAA=\"$HOME/.local/share/archon/bin:$PATH\" && echo $AAA", shell=True)
    # # command(["printenv"], output='all')
    # # subprocess.run("echo \"222\"", shell=True, check=True)
    # # subprocess.run(["clear"])
    # # subprocess.run("export AAA=\"$HOME/.local/share/archon/bin:$PATH\" && echo $AAA", shell=True)
    # subprocess.run(["printenv"], check=True)
    # logger.info("Welcome to the 'archon' Arch Linux setup tool.")

    install()

def uninstall_wrapper():
    uninstall()

if __name__ == "__main__":
    setup()

