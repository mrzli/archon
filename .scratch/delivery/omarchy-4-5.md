# Adapt Archon to Omarchy 4.5: delivery queue

Temporary queue. The rule for all items: setup assumes a clean Omarchy 4.5 install
and stays repeat-safe. Anything that only bridges from Omarchy 4.0 or an older
Archon configuration goes in `migrations/`, not setup.

## 1. Use Omarchy's keyboard defaults and per-monitor workspace display

Decision: `data/home/.config/hypr/input.lua` sets only `kb_layout = "us,hr"` and
`touchpad.natural_scroll = true`, removing `kb_options` entirely. Caps Lock, Shift +
Caps as Compose, and `SUPER + I` for switching layouts then come from Omarchy.
`data/home/.config/hypr/monitors.lua` drops the loop of persistent rules for
workspaces 1-10, so the bar uses Omarchy's display of 1-5 plus any in use.
`data/home/.config/hypr/bindings.lua` is unchanged and keeps `SUPER + SHIFT + H`
and `L`.

Footprint: the two Hyprland files, any tests or docs that mention them.
Depends on: none.
Status: agreed.

## 2. Make the VS Code workspace digit per monitor

Decision: `arc w vsc start` keeps its workspace digit, which now means that slot on
the focused monitor. Use Omarchy's `o.workspaces` helpers through `hyprctl dispatch`,
such as `o.workspaces.focus(3)` and `o.workspaces.move_window(3, false)`. They are
undocumented, as the user accepted: say so in the code, name what the code relies on,
and cover it with a test.

Footprint: `components/archon-cli/lib/archon/commands/workspaces/visual_studio_code/`,
its README, and `components/archon-cli/tests/visual_studio_code_test.rb`.
Depends on: none.
Status: agreed.

## 3. Align setup with a clean Omarchy 4.5

Decisions:

- Remove Superwhisper as desired state, in the removal part of setup, by running
  `omarchy remove dictation superwhisper` only when `superwhisper-bin` is installed.
- `install_voice_ai` adds `voxtype-bin` and `wtype`, which avoids the installer's
  confirmation prompt, then runs `omarchy install dictation voxtype`. Skip the
  installer when Voxtype is installed and already selected, in the style of
  `install_applications`. Drop setup's own copy of the default Voxtype configuration
  when the installer makes it redundant. `configure_voice_ai` keeps setting the model
  and GPU. A first run downloading `base.en` before `large-v3-turbo` is accepted.
- Remove `Fizzy` from `remove_unwanted_webapps`. Keep `Basecamp` and `HEY`. Keep
  removing `aether` and `obsidian`.
- Remove `claude` and `codex` from `install_mise_tools`. Omarchy declares them in its
  own mise configuration, and they install on first use. Keep `pnpm` and `shellcheck`.
- Simplify `setup.sh` to always run setup with `ruby`, because Ruby is in Omarchy's
  base packages. Setup still installs development Ruby through mise.

Footprint: `setup/setup.rb`, `setup.sh`, `setup/tests/`, and docs or the README where
they describe these steps.
Depends on: none.
Status: agreed.

## 4. Add the migration that removes unused packages

Decision: add a one-time script in `migrations/` that removes `rust`, `kdenlive`,
`obs-studio`, `signal-desktop`, `xournalpp`, and `dotnet-runtime-9.0` with
`omarchy pkg drop`, tolerating any that are absent, because the user runs it on each
machine. First check that no installed package requires one of them, and leave out
and report any that is required. Do not remove anything on the live system.

Footprint: `migrations/`.
Depends on: none.
Status: agreed.

## 5. Update outdated documentation

Decision: fix `docs/installation.md` for 4.5: the Wi-Fi steps use `SUPER + ALT + SPACE`,
which now opens Apps, so use the Network panel on `SUPER + CTRL + N`. Bring the list of
installer questions in line with the current installer in `omacom/omarchy-iso`,
including language, disk, and install mode. Update any other documentation these
changes make inaccurate, such as in the README.

Footprint: `docs/installation.md`, `README.md`.
Depends on: 1.
Status: agreed.
