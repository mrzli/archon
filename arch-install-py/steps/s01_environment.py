from types import SimpleNamespace
from util import get_cpu_vendor_id, get_architecture

def get_environment(logger):
    logger.info("Collecting environment information...")
    
    cpu_vendor = get_cpu_vendor()
    architecture = get_architecture()

    env = {
        "cpu_vendor": cpu_vendor,
        "architecture": architecture,
    }

    logger.info("All environment information collected successfully.")

    return SimpleNamespace(**env)

def validate_environment(logger, env):
    logger.info("Validating environment...")

    supported_cpu_vendors = ["intel", "amd"]
    if env.cpu_vendor not in supported_cpu_vendors:
        logger.info(f"Unsupported CPU vendor: {env.cpu_vendor}")
        raise Exception("Environment validation failed.")

    supported_architectures = ["x86_64"]
    if env.architecture not in supported_architectures:
        logger.info(f"Unsupported architecture: {env.architecture}")
        raise Exception("Environment validation failed.")

    logger.info("Environment validation completed successfully.")

def get_cpu_vendor():
    vendor_id = get_cpu_vendor_id()

    match vendor_id:
        case "GenuineIntel":
            return "intel"
        case "AuthenticAMD":
            return "amd"
        case _:
            return "<unknown>"
