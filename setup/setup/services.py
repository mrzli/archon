import subprocess
import sys
from .file_entries import parse_file_entries

def enable_and_start_services_from_file(file_path):
    services = parse_file_entries(file_path)
    enable_and_start_services(services)

def enable_and_start_services(services):
    subprocess.run(["sudo", "systemctl", "enable", "--now", *services], check=True)

def disable_and_stop_services_from_file(file_path):
    services = parse_file_entries(file_path)
    disable_and_stop_services(services)

def disable_and_stop_services(services):
    subprocess.run(["sudo", "systemctl", "disable", "--now", *services], check=True)
