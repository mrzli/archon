# TODO

- [ ] Add `archon admin` with alias `a` if available. Start with `voice start` and `voice stop`, using `systemctl --user start/stop voxtype.service` to load/unload the model without deleting it or changing login startup.
- [ ] Remap Codex queued-message navigation to `Alt+Shift+Up`, plus `Alt+Shift+Down` if a complementary action is supported. Preserve Herdr's `Alt+Up/Down` workspace navigation. Inspect the installed Codex version/source for supported action names and configuration syntax, and verify conflicts in native Herdr and Omarchy; do not rely on herdr-web bindings.
- [ ] Increase Voxtype's `audio.max_duration_secs` to 300 seconds (5 minutes).
