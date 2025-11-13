from .s01_input import setup_input
from .s02_disk import setup_disk
from .s03_chroot_prereq import setup_chroot_prerequisites

__all__ = [
    "setup_input",
    "setup_disk",
    "setup_chroot_prerequisites"
]