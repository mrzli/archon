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
    subprocess.run(["archon-install-paru"])
    packages_file = os.path.join(os.path.dirname(__file__), 'data/packages.txt')
    install_packages_from_file(packages_file)
