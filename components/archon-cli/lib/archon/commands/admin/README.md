# Administration

Use `archon admin --help` for help. Exit statuses are `0` for success, `1` for
operation failures, and `2` for invalid arguments.

## Battery

Battery commands require Lenovo's Linux conservation control and a `BAT0`
battery for status reporting:

```bash
archon admin battery status
archon admin battery conservation on
archon admin battery conservation off
```

Status shows the charge percentage, charging state, and conservation setting.
Enable conservation for mostly plugged-in use. Disable it to allow a full charge
before travel. The firmware determines the charge limit. Changing the setting
uses sudo and may prompt for a password. Repeating the current setting is safe
and needs no sudo. Unsupported machines report an error.

These commands do not install a startup service or change setup defaults.
Persistence across restarts depends on the firmware.

## GitHub SSH

Run Archon setup before using the installed CLI. Archon's initial HTTPS clone
and setup do not require GitHub SSH authentication. With Ruby and the required
tools available, you can also run the CLI directly from the repository:

```bash
components/archon-cli/bin/archon admin github ssh create
```

Create the key, add the public key to your account at
https://github.com/settings/keys, and then test authentication:

```bash
archon admin github ssh create
archon admin github ssh test

# Short form
arc a github ssh create
arc a github ssh test
```

`create` requires `ssh-keygen`, a running SSH agent accessible to `ssh-add`, and
`wl-copy` in a Wayland session. It creates an Ed25519 key without a passphrase at
`~/.ssh/id_ed25519_github`, with the existing `goran.mrzljak@gmail.com` comment.
It adds the key to the agent, adds the GitHub host configuration to
`~/.ssh/config`, and copies the public key to the clipboard. Registering the
public key with GitHub remains a manual step.

Repeating `create` reuses the key pair and avoids duplicate host entries. It
preserves unrelated SSH configuration and accepts the configuration produced
by the former root script. A different existing `Host github.com` block or an
incomplete key pair causes an error rather than overwriting existing files.
The config file is set to mode `600`.

`test` requires `ssh`. It runs `ssh -T git@github.com` and displays GitHub's
response. Confirm a first-connection host-key prompt only after checking
[GitHub's published fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints).
Successful authentication returns `0` from Archon, even though GitHub's lack of
shell access makes SSH itself return `1`. Failures return `1`.

## Voice

Voice commands require systemd and an installed Voxtype user service.

```bash
archon admin voice start
archon admin voice stop

# Short form
arc a voice start
arc a voice stop
```

Start dictation to load the configured model. Stop it before gaming to release
its memory. Starting an already running service or stopping an inactive one is
safe to repeat. These commands need no sudo, preserve downloaded models, and
do not change whether Voxtype starts at login.
