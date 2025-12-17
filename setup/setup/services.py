import subprocess
import sys
from .file_entries import parse_file_entries

def enable_and_start_services_from_file(services_file, is_user_service=False):
    services = parse_file_entries(services_file)
    enable_and_start_services(services, is_user_service=is_user_service)

def enable_and_start_services(services, is_user_service=False):
    cmd = get_services_command(services, "enable", is_user_service=is_user_service)
    subprocess.run(cmd, check=True)

def disable_and_stop_services_from_file(services_file, is_user_service=False):
    services = parse_file_entries(services_file)
    disable_and_stop_services(services, is_user_service=is_user_service)

def disable_and_stop_services(services, is_user_service=False):
    services_to_uninstall = get_services_to_uninstall(services, is_user_service=is_user_service)
    if services_to_uninstall and len(services_to_uninstall) > 0:
        cmd = get_services_command(services_to_uninstall, "disable", is_user_service=is_user_service)
        subprocess.run(cmd, check=True)

def get_services_command(services, action, is_user_service=False):
    return [
        *(["sudo"] if not is_user_service else []),
        "systemctl",
        *(["--user"] if is_user_service else []),
        action,
        "--now",
        *services
    ]

def get_services_to_uninstall(services, is_user_service=False):
    existing_services = get_existing_services(is_user_service=is_user_service)
    services_to_uninstall = [
        service
        for service in services
        if service in existing_services
    ]
    return services_to_uninstall

def get_existing_services(is_user_service=False):
    cmd = [
        *(["sudo"] if not is_user_service else []),
        "systemctl",
        *(["--user"] if is_user_service else []),
        "list-unit-files",
        "--type=service",
        "--no-pager",
        "--no-legend"
    ]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=True
    )
    services = [
        line.split()[0]
        for line in (result.stdout or "").splitlines()
        if line.strip()
    ]
    return services
