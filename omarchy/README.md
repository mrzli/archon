# Setup

Clone the repo locally:

```bash
curl -sSL https://raw.githubusercontent.com/mrzli/archon/master/repo.sh | bash
```

Uninstall unneeded packages, install needed packages, configure settings.

```bash
~/.config/archon/omarchy/setup.sh
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

### Logins

- Log into GMail, Youtube, and GitHub in Chromium.

### GitHub SSH Key

```bash
~/.config/archon/omarchy/github-ssh-create.sh
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
~/.config/archon/omarchy/github-ssh-test.sh
```
