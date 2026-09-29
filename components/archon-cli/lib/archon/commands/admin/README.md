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
