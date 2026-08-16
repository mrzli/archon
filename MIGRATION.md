# Omarchy 4 migration

This file records one-time manual changes to apply to an existing installation after upgrading to Omarchy 4. Add steps only when they are actually being handled; do not use this file for predicted work.

## 1. Remove stale Typora files

Remove Typora's leftover launcher and configuration, then refresh the application menu:

```bash
rm -f ~/.local/share/applications/typora.desktop
rm -rf ~/.config/Typora
update-desktop-database ~/.local/share/applications
```

## 2. Remove unwanted default packages

Check that the package list still matches `packages_to_remove` in `setup.sh`, then run:

```bash
omarchy pkg drop aether obsidian
```

## 3. Remove unwanted default web apps

Run the removal command once for each web app. It also removes associated icons and refreshes the application menu database.

```bash
webapps_to_remove=(Basecamp Fizzy HEY)

for webapp in "${webapps_to_remove[@]}"; do
  omarchy webapp remove "$webapp"
done
```

## 4. Install personal Hyprland configuration

Run from the repository root. These files replace the existing user overrides for monitors, keyboard input, and custom bindings.

```bash
hypr_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
mkdir -p "$hypr_config_dir"
cp data/config/hypr/{monitors.lua,input.lua,bindings.lua} "$hypr_config_dir/"

hyprctl reload
hyprctl configerrors
```

## 5. Move custom Bash configuration out of `.bashrc`

In `~/.bashrc`, delete `# Custom omarchy configuration` and the custom configuration beneath it. Then run from the repository root:

```bash
install -Dm644 data/config/archon/bashrc ~/.config/archon/bashrc
echo 'source "${XDG_CONFIG_HOME:-$HOME/.config}/archon/bashrc"' >> ~/.bashrc
```

Open a new terminal afterward.
