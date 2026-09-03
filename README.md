# Setup

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
archon_dir="${XDG_DATA_HOME:-$HOME/.local/share}/archon"
mkdir -p "$(dirname "$archon_dir")"
git \
  -c credential.helper= \
  -c credential.helper='!gh auth git-credential' \
  clone https://github.com/mrzli/archon.git "$archon_dir"
```

Run the setup script to apply the managed system configuration:

```bash
~/.local/share/archon/setup.sh
```

The setup script overlays `data/home/` onto the user's home directory. Files
already present at managed paths are updated; unrelated home files are left
untouched.

### Tmux Workspaces

Setup installs five tmux launchers in `~/projects/workspaces`:

| Launcher | Responsibility |
| --- | --- |
| `hubs.sh` | Persistent shell sessions rooted at the workspace, personal-project, and JavaScript-library directories. |
| `flashcards.sh` | Frontend and backend flashcards sessions, including their editor, Codex, development, and shell windows. |
| `jslibs.sh` | One editor, Codex, and shell session for each immediate Git repository under the JavaScript-library root. |
| `misc-projects.sh` | Editor, Codex, and shell sessions for the configured miscellaneous personal projects. |
| `all.sh` | Starts or stops all four groups. |

Every launcher requires exactly one action:

```bash
~/projects/workspaces/hubs.sh start
~/projects/workspaces/hubs.sh stop
~/projects/workspaces/all.sh start
~/projects/workspaces/all.sh stop
```

Starts leave existing sessions unchanged, stops tolerate absent sessions, and
missing configured directories are reported and skipped. `all.sh start` runs
every group and then attaches to the `workspaces` session, or switches the
current tmux client to it when already inside tmux. If any group fails, all
remaining groups are still attempted, the aggregate command returns nonzero,
and it does not attach or switch. Aggregate stop uses reverse group order and
also reports partial failures.

`projects/workspaces` is a managed replacement directory. On setup, its
destination is replaced with the repository version, which intentionally
removes obsolete launcher files from `~/projects/workspaces`.

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
- Log into Steam.

### GitHub SSH Key

```bash
~/.local/share/archon/github-ssh-create.sh
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
~/.local/share/archon/github-ssh-test.sh
```

Now that the SSH key is set up, change the `archon` repo to use SSH instead of HTTPS:

```bash
git -C "${XDG_DATA_HOME:-$HOME/.local/share}/archon" remote set-url origin git@github.com:mrzli/archon.git
```

### Synchronize Personal Projects

```bash
"$HOME/projects/personal/projects.mjs" sync
```

This updates existing repositories and clones missing repositories into
`~/projects/personal/<owner>/<repository>`. It preserves repositories with
local changes instead of updating their checked-out branches.

## Update Archon Repo

```bash
archon_dir="${XDG_DATA_HOME:-$HOME/.local/share}/archon"
git -C "$archon_dir" pull --ff-only
```
