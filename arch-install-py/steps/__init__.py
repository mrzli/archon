from .s01_input import collect_inputs
from .s02_disk import setup_disk
from .s03_chroot_prereq import setup_chroot_prerequisites
from .s04_chroot_run import chroot_run
from .s05_finalize import finalize_arch_installation

__all__ = [
    "collect_inputs",
    "setup_disk",
    "setup_chroot_prerequisites",
    "chroot_run",
    "finalize_arch_installation",
]