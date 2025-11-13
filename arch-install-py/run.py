from pprint import pprint
from steps import process_installation_inputs, setup_disk

inputs = process_installation_inputs()

print("Installation Inputs Collected:")
pprint(inputs)

setup_disk(inputs)
