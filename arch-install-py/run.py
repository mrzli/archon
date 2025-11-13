from pprint import pprint
import subprocess
from steps import setup_input, setup_disk

subprocess.run(["clear"])

inputs = setup_input()

# print("Installation Inputs Collected:")
# pprint(inputs)

setup_disk(inputs)
