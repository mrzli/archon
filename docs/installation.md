# Installing a new machine

You can follow instructions from [here](https://learn.omacom.io/2/the-omarchy-manual/50/getting-started).

## Create Bootable USB

Download iso from https://omarchy.org/.

### Install Software

Check if you have `caligula` installed:

```bash
caligula --version
```

If you don't have it, install it:

```bash
sudo pacman -S caligula
```

### Create Bootable USB

Find out the device name of your USB drive:

```bash
lsblk
```

Burn the iso to the USB drive:

```bash
sudo caligula /path/to/omarchy.iso
```

Skip unnecessary steps, and it will offer you a target device. Select it. Don't know what the exact steps after this are, but should be trivial.

## Install Omarchy

I suspect the system will ask you for some information:

- Username, e.g. `mrzli`.
- Password.
- Full name.
- Email address.
- Hostname, e.g. `mrzli-arch`.
- Timezone, e.g. `Europe/Zagreb`.
- Keyboard layout, e.g. `us`.

## Setup System

Login to GitHub CLI:

```bash
gh auth login \
  --hostname github.com \
  --git-protocol ssh \
  --web \
  --skip-ssh-key
# Follow the prompts and login via browser.
```

Clone the repo locally:

```bash
archon_dir="${XDG_DATA_HOME:-$HOME/.local/share}/archon/repo"
mkdir -p "$(dirname "$archon_dir")"
git \
  -c credential.helper= \
  -c credential.helper='!gh auth git-credential' \
  clone https://github.com/mrzli/archon.git "$archon_dir"
```

Run the setup script to apply the managed system configuration:

```bash
"${XDG_DATA_HOME:-$HOME/.local/share}/archon/repo/setup.sh"
```

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
  - ChatGPT

- Add extensions:
  - Bitwarden.
    - Also log into it.
  - StayFocusd.
  - uBlock Origin Lite.
  - Redux DevTools (if you use it).

### Logins

- VS Code:
  - Sign into VS Code Copilot.
  - Sign into Codex.
- Claude Code: run `claude` once and log in.
- Log into Steam.

### GitHub SSH Key

Run Archon setup first, as described above. It installs the CLI;
the initial HTTPS clone and setup do not require this SSH key.

```bash
archon admin github ssh create
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
archon admin github ssh test
```

Now that the SSH key is set up, change the `archon` repo to use SSH instead of HTTPS:

```bash
git -C "${XDG_DATA_HOME:-$HOME/.local/share}/archon/repo" remote set-url origin git@github.com:mrzli/archon.git
```

## Update Archon Repo

```bash
archon_dir="${XDG_DATA_HOME:-$HOME/.local/share}/archon/repo"
git -C "$archon_dir" pull --ff-only
```
