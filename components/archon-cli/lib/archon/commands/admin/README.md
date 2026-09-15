# Administration

Requires systemd and an installed Voxtype user service.

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

Use `archon admin --help` for help. Exit statuses are `0` for success, `1` for
service-operation failures, and `2` for invalid arguments.
