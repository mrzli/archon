import subprocess
import sys

def install_packages_from_file(file_path):
    packages = parse_packages(file_path)
    install_packages(packages)

def install_packages(packages):
    subprocess.run(["paru", "-S", "--noconfirm", *packages], check=True)

def uninstall_packages_from_file(file_path):
    packages = parse_packages(file_path)
    uninstall_packages(packages)

def uninstall_packages(packages):
    subprocess.run(["paru", "-Rns", "--noconfirm", *packages], check=True)

def parse_packages(file_path):
    packages = []
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            # Extract package name before any comment.
            package = line.split(maxsplit=1)[0]
            if package:
                packages.append(package)
    return packages