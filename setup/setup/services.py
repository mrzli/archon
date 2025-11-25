import subprocess
import sys
from .file_entries import parse_file_entries

def enable_and_start_services_from_file(file_path, is_user_service=False):
    services = parse_file_entries(file_path)
    enable_and_start_services(services, is_user_service=is_user_service)

def enable_and_start_services(services, is_user_service=False):
    cmd = get_command(services, "enable", is_user_service=is_user_service)
    subprocess.run(["sudo", *cmd], check=True)

def disable_and_stop_services_from_file(file_path):
    services = parse_file_entries(file_path)
    disable_and_stop_services(services)

def disable_and_stop_services(services, is_user_service=False):
    cmd = get_command(services, "disable", is_user_service=is_user_service)
    subprocess.run(["sudo", *cmd], check=True)

def get_command(services, action, is_user_service=False):
    base_cmd = ["systemctl"]
    if is_user_service:
        base_cmd.insert(0, "--user")
    return [*base_cmd, action, "--now", *services]
