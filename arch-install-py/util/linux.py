import subprocess

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

def command(
    args,
    shell=False,
    output='error-only'
):
    switch output:
        case 'none':
            return subprocess.run(
                args,
                capture_output=True,
                shell=shell,
                text=True,
                check=True
            )
        case 'error-only':
            return subprocess.run(
                args,
                stdout=subprocess.PIPE,
                stderr=None,
                shell=shell,
                text=True,
                check=True
            )
        case 'all':
            return subprocess.run(
                args,
                capture_output=False,
                shell=shell,
                text=True,
                check=True
            )
        case _:
            raise ValueError(f"Invalid output option: {output}")
