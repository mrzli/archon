# Setup

Clone the repo locally:

```bash
curl -sSL https://raw.githubusercontent.com/mrzli/archon/master/repo.sh | bash
```

Uninstall unneeded packages, install needed packages, configure settings.

```bash
~/.config/archon/omarchy/setup.sh
```

Do some manuual steps:

- Log into GMail, Youtube, and GitHub in Chromium.

Install GitHub SSH key:

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
