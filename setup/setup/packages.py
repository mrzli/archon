import subprocess
import sys
from .file_entries import parse_file_entries

def install_packages_from_file(packages_file):
    packages = parse_file_entries(packages_file)
    install_packages(packages)

def install_packages(packages):
    subprocess.run(
        [
            "paru",
            "-S",
            *packages
        ],
        check=True
    )

def uninstall_packages_from_file(packages_file):
    packages = parse_file_entries(packages_file)
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
        check=False
    )
    installed_packages = [
        line.strip()
        for line in (result.stdout or "").splitlines()
        if line.strip()
    ]
    # Print installed packages for debugging
    print(f"Installed packages subset: {installed_packages}")
    return installed_packages
