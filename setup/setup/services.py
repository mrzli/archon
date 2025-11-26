import subprocess
import sys
from .file_entries import parse_file_entries

def enable_and_start_services_from_file(services_file, is_user_service=False):
    services = parse_file_entries(services_file)
    enable_and_start_services(services, is_user_service=is_user_service)

def enable_and_start_services(services, is_user_service=False):
    cmd = get_command(services, "enable", is_user_service=is_user_service)
    subprocess.run(cmd, check=True)

def disable_and_stop_services_from_file(services_file):
    services = parse_file_entries(services_file)
    disable_and_stop_services(services)

def disable_and_stop_services(services, is_user_service=False):
    cmd = get_command(services, "disable", is_user_service=is_user_service)
    subprocess.run(cmd, check=True)

def get_command(services, action, is_user_service=False):
    return [
        *(["sudo"] if not is_user_service else []),
        "systemctl",
        *(["--user"] if is_user_service else []),
        action,
        "--now",
        *services
    ]