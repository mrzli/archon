# Omarchy 4 migration

This file records one-time manual changes to apply to an existing installation after upgrading to Omarchy 4. Add steps only when they are actually being handled; do not use this file for predicted work.

## 1. Remove stale application launchers and configuration

Removing a package can leave its application-menu launcher and configuration behind. Perform this cleanup once on each system; the affected applications may differ.

1. Check the application menu for entries that no longer launch.
2. Confirm that the application is absent:

   ```bash
   command -v <executable>
   pacman -Q <package>
   ```

3. Find matching launcher and configuration files:

   ```bash
   find ~/.local/share/applications ~/.config ~/.local/share ~/.cache \
     -maxdepth 2 -iname '*<app-name>*' -print
   ```

4. Inspect the results and preserve any user data. Move only confirmed leftovers to the trash:

   ```bash
   gio trash <leftover-paths...>
   ```

5. Refresh the application menu database:

   ```bash
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

Replace the old appended block with the managed configuration file. Run from the repository root:

```bash
sed -i '/^# Custom omarchy configuration$/,$d' ~/.bashrc
install -Dm644 data/config/archon/bashrc ~/.config/archon/bashrc
echo 'source "${XDG_CONFIG_HOME:-$HOME/.config}/archon/bashrc"' >> ~/.bashrc
```

Open a new terminal afterward.
