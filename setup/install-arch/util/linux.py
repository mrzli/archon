import re
import subprocess

def command(
    args,
    shell=False,
    check=True,
    output='error-only'
):
    match output:
        case 'none':
            return subprocess.run(
                args,
                capture_output=True,
                shell=shell,
                text=True,
                check=check
            )
        case 'error-only':
            return subprocess.run(
                args,
                stdout=subprocess.PIPE,
                stderr=None,
                shell=shell,
                text=True,
                check=check
            )
        case 'all':
            return subprocess.run(
                args,
                capture_output=False,
                shell=shell,
                text=True,
                check=check
            )
        case _:
            raise ValueError(f"Invalid output option: {output}")

def get_block_device_names():
    try:
        result = subprocess.run(
            ['lsblk', '-o', 'NAME', '-d', '-n'], 
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip().split('\n')[1:]  # Skip header
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"Error running lsblk: {e}")
        return []

def get_block_device_uuid(device_name):
    result = subprocess.run(
        ['blkid', device_name, '-s', 'UUID', '-o', 'value'],
        capture_output=True,
        text=True,
        check=True
    )
    uuid = result.stdout.strip()
    if not uuid:
        raise ValueError(f"UUID not found for device: {device_name}")

    return uuid

def get_cpu_vendor_id():
    result = subprocess.run(
        "lscpu | grep 'Vendor ID'",
        shell=True,
        capture_output=True,
        text=True,
        check=True
    )
    cpu_info = result.stdout.strip()
    vendor_id_match = re.search(r'Vendor ID:\s+(\S+)', cpu_info)
    vendor_id = vendor_id_match.group(1) if vendor_id_match else None

    return vendor_id

def get_architecture():
    result = subprocess.run(
        ["uname", "-m"],
        capture_output=True,
        text=True,
        check=True
    )
    architecture = result.stdout.strip()
    return architecture
