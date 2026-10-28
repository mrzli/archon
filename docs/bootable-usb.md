# Creating a bootable USB drive

This guide writes the Omarchy ISO to a USB drive, which the new computer then boots from to install Omarchy. It is the first step of [installing a new machine](installation.md).

You need a USB drive and an existing Linux computer. Writing the ISO erases everything on the drive.

1. Download the Omarchy ISO from [omarchy.org](https://omarchy.org/).

2. Install Caligula, a tool for writing disk images, if it is not installed yet:

   ```bash
   caligula --version || sudo pacman -S caligula
   ```

3. Insert the USB drive. If you are unsure which device it is, list the drives:

   ```bash
   lsblk
   ```

4. Write the ISO to the drive:

   ```bash
   sudo caligula burn /path/to/omarchy.iso
   ```

5. Skip the optional steps. When Caligula lists the target devices, select the USB drive and confirm.
