from pprint import pprint
from steps import process_installation_inputs

inputs = process_installation_inputs()

print("Installation Inputs Collected:")
pprint(inputs)