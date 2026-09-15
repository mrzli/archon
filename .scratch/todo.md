# TODO

- [x] Add `archon admin` with alias `a`. `voice start` and `voice stop` control the Voxtype user service without deleting models or changing login startup.
- [x] Provision Codex navigation through Archon setup: `edit_queued_message = "alt-shift-up"` and `prompt_stack_back = "alt-shift-down"` under `[tui.keymap.chat]`. Preserve other Codex settings and Herdr shortcuts. Validated with Codex 0.154.0; restart Codex to load the bindings. Physical key delivery through Herdr still needs a user check.
- [x] Increase Voxtype's `audio.max_duration_secs` to 300 seconds (5 minutes).
- [x] Add the Intel/NVIDIA video workaround in `setup/workarounds.rb`, with hardware detection and a manual removal command. Track Omarchy issue #8215.
- [x] Verify the video workaround on the laptop after a fresh login, including the affected application and connected monitors.
