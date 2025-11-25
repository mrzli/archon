import subprocess
import sys
from .file_entries import parse_file_entries

def install_packages_from_file(file_path):
    packages = parse_file_entries(file_path)
    install_packages(packages)

def install_packages(packages):
    subprocess.run(["sudo", "paru", "-S", "--noconfirm", *packages], check=True)

def uninstall_packages_from_file(file_path):
    packages = parse_file_entries(file_path)
    uninstall_packages(packages)

def uninstall_packages(packages):
    subprocess.run(["sudo", "pacman", "-Rns", "--noconfirm", *packages], check=True)
