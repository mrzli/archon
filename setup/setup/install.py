import os
import subprocess
from util import (
  command,
  LogLevel,
  Logger,
  LoggerConsoleHandler,
  LoggerFileHandler
)
from .config import setup_config
from .packages import install_packages_from_file
from .services import enable_and_start_services_from_file

def install():
    repo_data_dir = os.path.join(os.path.dirname(__file__), '../..', 'data')
    data_dir = os.path.join(os.path.dirname(__file__), 'data')

    subprocess.run(['clear'])

    # Ensure sudo password is provided.
    subprocess.run(['sudo', '-v'])

    setup_config(repo_data_dir)

    subprocess.run(['sudo', 'pacman', '-Syu', '--noconfirm'])
    subprocess.run(["archon-install-paru"])

    packages_file = os.path.join(data_dir, 'packages.txt')
    install_packages_from_file(packages_file)

    services_file = os.path.join(data_dir, 'services.txt')
    enable_and_start_services_from_file(services_file)
    user_services_file = os.path.join(data_dir, 'services-user.txt')
    enable_and_start_services_from_file(user_services_file, is_user_service=True)

