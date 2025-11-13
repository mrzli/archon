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
