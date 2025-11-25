import os
import subprocess
from util import (
  command,
  LogLevel,
  Logger,
  LoggerConsoleHandler,
  LoggerFileHandler
)
from .packages import install_packages_from_file

def install():
    subprocess.run(['clear'])

    # Ensure sudo password is provided.
    subprocess.run(['sudo', '-v'])

    subprocess.run(['sudo', 'pacman', '-Syu', '--noconfirm'])
    subprocess.run(["archon-install-paru"])
    packages_file = os.path.join(os.path.dirname(__file__), 'data/packages.txt')
    install_packages_from_file(packages_file)
