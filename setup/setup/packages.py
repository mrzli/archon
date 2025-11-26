import subprocess
import sys
from .file_entries import parse_file_entries

def install_packages_from_file(file_path):
    packages = parse_file_entries(file_path)
    install_packages(packages)

def install_packages(packages):
    subprocess.run(["paru", "-S", "--noconfirm", *packages], check=True)

def uninstall_packages_from_file(file_path):
    packages = parse_file_entries(file_path)
    uninstall_packages(packages)

def uninstall_packages(packages):
    installed_packages = get_installed_packages_subset(packages)
    if installed_packages:
        subprocess.run(
            ["sudo", "pacman", "-Rns", "--noconfirm", *installed_packages],
            check=True
        )

def get_installed_packages_subset(packages):
    result = subprocess.run(
        ["pacman", "-Qq", *packages],
        capture_output=True,
        text=True,
        check=True
    )
    installed_packages = result.stdout.strip().split('\n')
    return installed_packages
