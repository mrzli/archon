import os
import subprocess
from util import (
  command,
  LogLevel,
  Logger,
  LoggerConsoleHandler,
  LoggerFileHandler
)
from .packages import uninstall_packages_from_file

def uninstall():
    # Ensure sudo password is provided.
    subprocess.run(['sudo', '-v'])

    subprocess.run(['archon-uninstall-paru'])
    packages_file = os.path.join(os.path.dirname(__file__), 'data/packages.txt')
    uninstall_packages_from_file(packages_file)