from util import command
import shutil

def chroot_run(logger, inputs):
    username = inputs.username
    user_password = inputs.user_password
    device_partition_efi = inputs.device_partition_efi
    device_partition_root = inputs.device_partition_root
    vol_group_name = inputs.vol_group_name

    logger.command(["mkdir", "-p", "/mnt/arch-install"])

    # Copy files from chroot dir, which is in parent of this script dir
    # use python functions
    # so this script then "../chroot", then copy all from there to "/mnt/arch-install"
    script_dir = shutil.os.path.dirname(shutil.os.path.abspath(__file__))
    python_project_dir = shutil.os.path.abspath(shutil.os.path.join(script_dir, ".."))
    shutil.copytree(python_project_dir, "/mnt/arch-install", dirs_exist_ok=True)

    chroot_cmd = (
        "pacman -Syu --noconfirm python && "
        "cd /arch-install && "
        'python chroot_run.py "{}" "{}" "{}" "{}" "{}"'.format(
            username,
            user_password,
            device_partition_efi,
            device_partition_root,
            vol_group_name
        )
    )

    logger.command(["arch-chroot", "/mnt", "/bin/bash", "-c", chroot_cmd], output='all')

    logger.command(["rm", "-rf", "/mnt/arch-install"])