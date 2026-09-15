# TODO

- [x] Add `archon admin` with alias `a`. `voice start` and `voice stop` control the Voxtype user service without deleting models or changing login startup.
- [x] Provision Codex navigation through Archon setup: `edit_queued_message = "alt-shift-up"` and `prompt_stack_back = "alt-shift-down"` under `[tui.keymap.chat]`. Preserve other Codex settings and Herdr shortcuts. Validated with Codex 0.154.0; restart Codex to load the bindings. Physical key delivery through Herdr still needs a user check.
- [ ] Increase Voxtype's `audio.max_duration_secs` to 300 seconds (5 minutes).
- [ ] Investigate intermittent video playback problems on the Lenovo Legion laptop, possibly related to Intel/NVIDIA hybrid graphics. If needed, add an Archon workaround in one separate file, easy to remove once the underlying issue is fixed. Call this file 'hacks.rb', or 'workarounds.rb', or something else appropriate.
