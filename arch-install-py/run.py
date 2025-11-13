from pprint import pprint
import subprocess
from steps import (
  setup_input,
  setup_disk,
  setup_chroot_prerequisites,
  chroot_run,
  finalize_arch_installation
)

subprocess.run(["clear"])

inputs = setup_input()

# print("Installation Inputs Collected:")
# pprint(inputs)

setup_disk(inputs)
setup_chroot_prerequisites(inputs)
chroot_run(inputs)
