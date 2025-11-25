from util import command
import shutil

def chroot_run(logger, env, inputs):
    cpu_vendor = env.cpu_vendor
    username = inputs.username
    user_password = inputs.user_password
    device_partition_efi = inputs.device_partition_efi
    device_partition_root = inputs.device_partition_root
    luks_mapping_name = inputs.luks_mapping_name
    use_encryption = inputs.use_encryption
    use_lvm = inputs.use_lvm
    iana_tz_area = inputs.iana_tz_area
    iana_tz_location = inputs.iana_tz_location

    logger.info("Preparing chroot environment...")

    logger.command(["mkdir", "-p", "/mnt/archon"])

    script_dir = shutil.os.path.dirname(shutil.os.path.abspath(__file__))
    python_project_dir = shutil.os.path.abspath(shutil.os.path.join(script_dir, ".."))
    shutil.copytree(python_project_dir, "/mnt/archon", dirs_exist_ok=True)

    chroot_params = [
        cpu_vendor,
        username,
        user_password,
        device_partition_efi,
        device_partition_root,
        luks_mapping_name,
        str(use_encryption),
        str(use_lvm),
        iana_tz_area,
        iana_tz_location
    ]
    chroot_params_quoted = [f'"{param}"' for param in chroot_params]
    chroot_params_str = " ".join(chroot_params_quoted)

    chroot_cmd = (
        "pacman -Syu --noconfirm python && "
        "cd /archon && "
        f"python chroot_run.py {chroot_params_str}"
    )

    command(["arch-chroot", "/mnt", "/bin/bash", "-c", chroot_cmd], output='all')

    logger.command(["rm", "-rf", "/mnt/archon"])

    logger.info("Chroot setup completed successfully.")