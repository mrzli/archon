# Installing a new machine

This guide turns a new computer into my workstation: install Omarchy, run Archon's setup, and finish a few manual steps. The [Omarchy manual](https://learn.omacom.io/2/the-omarchy-manual/50/getting-started) covers the Omarchy installation in more detail.

## Create a bootable USB drive

On an existing Linux computer, download and run the script that writes the Omarchy ISO to a USB drive. It guides you through each step and erases the drive you choose.

```bash
curl -fsSLO https://raw.githubusercontent.com/mrzli/archon/master/scripts/burn-omarchy-usb.sh
bash burn-omarchy-usb.sh
```

## Install Omarchy

Boot the new computer from the USB drive and follow the installer. It asks for these, in order:

1. Language.
2. Keyboard layout, such as `English (US)`.
3. Timezone, such as `Europe/Berlin`.
4. Username, such as `alex`.
5. Password, entered twice. It is used for the user, root, and disk encryption when enabled.
6. Hostname, such as `workstation`. Press `ENTER` on an empty field to use `omarchy`.
7. Confirmation of these answers.
8. Install disk.
9. Installation mode: **Full disk install**, **Free space install (alongside existing data)**, or **Choose a different disk**. The installer skips this question and uses a full disk install when the disk has no partition table or no free space. It offers the free space install only on UEFI computers.
10. Confirmation of the install. A full disk install overwrites everything on the disk. The install is encrypted unless you press `CTRL + C` at this question.

## Connect to the internet

Skip this if the computer is already online, such as over ethernet. The installer does not set up Wi-Fi. Signing in to GitHub, cloning, and setup all need the internet.

1. Press `SUPER + CTRL + N` to open the Network panel.
2. Press the down arrow to show the selection, select the network with the arrow keys, and press `ENTER`. You can also click the network.
3. If asked, enter the Wi-Fi password and press `ENTER`.
4. Wait for the network to show **Connected**, then press `ESCAPE` to close the panel.

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
