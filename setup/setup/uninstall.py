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
from .services import disable_and_stop_services_from_file

def uninstall():
    data_dir = os.path.join(os.path.dirname(__file__), 'data')

    subprocess.run(['clear'])

    # Ensure sudo password is provided.
    subprocess.run(['sudo', '-v'])

    subprocess.run(['archon-uninstall-paru'])

    user_services_file = os.path.join(data_dir, 'services-user.txt')
    disable_and_stop_services_from_file(user_services_file, is_user_service=True)
    services_file = os.path.join(data_dir, 'services.txt')
    disable_and_stop_services_from_file(services_file)
    packages_file = os.path.join(data_dir, 'packages.txt')
    uninstall_packages_from_file(packages_file)