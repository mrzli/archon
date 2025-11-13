from pprint import pprint
import subprocess
from steps import process_installation_inputs, setup_disk

subprocess.run(["clear"])

inputs = process_installation_inputs()

# print("Installation Inputs Collected:")
# pprint(inputs)

setup_disk(inputs)
