# Installing a new machine

This guide turns a new computer into my workstation: install Omarchy, run Archon's setup, and finish a few manual steps. The [Omarchy manual](https://learn.omacom.io/2/the-omarchy-manual/50/getting-started) covers the Omarchy installation in more detail.

## Create a bootable USB drive

Write the Omarchy ISO to a USB drive, as described in [Creating a bootable USB drive](bootable-usb.md).

## Install Omarchy

Boot the new computer from the USB drive and follow the installer. It asks for:

- Keyboard layout, such as `us`.
- Username, such as `alex`.
- Password.
- Full name.
- Email address.
- Hostname, such as `workstation`.
- Timezone, such as `Europe/Berlin`.

## Connect to the internet

Skip this if the installer already connected to Wi-Fi or the computer uses ethernet. Signing in to GitHub, cloning, and setup all need the internet.

1. Open the Wi-Fi settings. Press `SUPER + ALT + SPACE`, select **Setup**, and press `ENTER`. Then select **Wi-Fi** and press `ENTER`.
2. Press `TAB` to move to the list of networks, select the network with the arrow keys, and press `ENTER`.
3. Enter the Wi-Fi password and press `ENTER`.

## Run setup

Sign in to the GitHub CLI:

```bash
gh auth login \
  --hostname github.com \
  --git-protocol ssh \
  --web \
  --skip-ssh-key
# Follow the prompts and sign in through the browser.
```

Clone this repository:

```bash
archon_dir="${XDG_DATA_HOME:-$HOME/.local/share}/archon/repo"
mkdir -p "$(dirname "$archon_dir")"
git \
  -c credential.helper= \
  -c credential.helper='!gh auth git-credential' \
  clone https://github.com/mrzli/archon.git "$archon_dir"
```

Run the setup script:

```bash
"${XDG_DATA_HOME:-$HOME/.local/share}/archon/repo/setup.sh"
```

## Manual steps

### Chromium

Sign in to:

- Gmail
- YouTube
- GitHub
- X
- AI assistants, such as Claude, ChatGPT, and Grok

Add these extensions:

- Bitwarden, and sign in to it.
- StayFocusd.
- uBlock Origin Lite.
- Redux DevTools, if needed.

### Applications

Sign in to:

- Claude Code, by running `claude` once.
- Codex, by running `codex` once.
- Any remaining applications, such as Steam or Battle.net.

### GitHub SSH key

Setup installs the Archon CLI, which creates the key. The initial HTTPS clone and setup do not need it.

```bash
archon admin github ssh create
# Copies the public key to the clipboard.
```

Add the key to GitHub:

1. Go to <https://github.com/settings/keys>.
2. Click **New SSH key**.
3. Enter a name, such as `workstation`.
4. Paste the public key from the clipboard.
5. Click **Add SSH key**.

Test the connection:

```bash
archon admin github ssh test
```

## Clone my projects

Clone all my repositories over SSH, including this one at `~/projects/personal/mrzli/archon`:

```bash
arc projects sync
```

From now on, setup runs from that checkout. To apply a change, pull it there and run `arc setup`. Setup no longer uses the first clone in `~/.local/share/archon/repo`.

## Set up secrets

Create the secrets store, which lists every secret name with an empty value:

```bash
arc projects secrets init
```

Open `~/.local/share/archon/secrets/secrets.env` and fill in the values, for example from the password manager.

Generate each project's `.env` file from its template:

```bash
arc projects secrets sync
```
