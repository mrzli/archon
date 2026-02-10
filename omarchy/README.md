# Setup

## Create Bootable USB



## Archinstall

Here are the instructions:

- https://learn.omacom.io/2/the-omarchy-manual/96/manual-installation

### Explained Steps

Make sure you have the latest version of archinstall:

```bash
pacman -Sy archinstall
```

Run `archinstall` and follow the prompts:

- Mirrors and repositories: Select a region closest to you.
- Disk configuration:
  - Partitioning:
    - Disk configuration type: Use a best-effort default partition layout
    - Select the disk to partition.
    - Filesystem: btrfs
    - Would you like to use BTRFS subvolumes with a default strcucture?: Yes
    - Would you like to use compression or disable CoW?: Use compression
  - Disk encryption:
    - Encryption type: LUKS
    - Encryption passowrd:
      - Password: Set a password and confirm.
    - Iteration time: 2000ms
    - Partitions: Select your partition.
- Bootloader: Limine.
- Hostname: mrzli-arch
- Authentication:
  - Root password: Set a password and confirm (same as encryption password).
  - User account:
    - Add a user
      - Username: mrzli
      - Password: Set a password and confirm (same as root password).
      - Superuser: Yes
    - Confirm and exit
- Applications:
  - Audio: pipewire
- Network configuration: Copy ISO network configuration to installation
- Timezone: Europe/Zagreb (scroll up from UTC, it is faster)

Install.

Select reboot.

Enter disk encryption password to boot into the system, and log in with the user credentials.

## Setup Omarchy

Run:

```bash
curl -fsSL https://omarchy.org/install | bash
```

Enter password when prompted.

Reboot when prompted.

After installation, if you don't see the Omarchy boot option, go to UEFI and disable Limine boot option.

## Setup System

Clone the repo locally:

```bash
curl -sSL https://raw.githubusercontent.com/mrzli/archon/master/repo.sh | bash
```

Uninstall unneeded packages, install needed packages, configure settings.

```bash
~/.local/share/archon/omarchy/setup.sh
```

Reboot after the script finishes.

## Manual Steps

### Wi-Fi

- Go to Wi-Fi settings:
  - Press `SUPER + ALT + SPACE`.
  - Select 'Setup' and press `ENTER`.
  - Select 'Wi-Fi' and press `ENTER`.
- Select the SSID:
  - Press `TAB` to focus on the list of available networks:
  - Use arrow keys to select your network.
  - Press `ENTER`.
- Enter the Wi-Fi password and press `ENTER`.

### Chromium

- Log into:
  - GMail
  - Youtube
  - GitHub
  - X
  - Grok

- Add BitWarden extension and log in.

### Logins

- Sign into VS Code Copilot.
- Log into Steam.

### GitHub SSH Key

```bash
~/.local/share/archon/omarchy/github-ssh-create.sh
# Automatically copies the public key to clipboard.
```

Setup the SSH key in your GitHub account:

- Go to https://github.com/settings/keys.
- Click "New SSH key".
- Set the name, e.g. "mrzli-arch".
- Paste the public key from clipboard.
- Click "Add SSH key".

Test the SSH connection:

```bash
~/.local/share/archon/omarchy/github-ssh-test.sh
```

### Create Projects

```bash
~/.local/share/archon/omarchy/create-projects.sh
```
