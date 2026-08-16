# Migration

Apply these one-time steps to an existing installation.

## 1. Remove stale Typora files

Remove Typora's leftover launcher and configuration, then refresh the application menu:

```bash
rm -f ~/.local/share/applications/typora.desktop
rm -rf ~/.config/Typora
update-desktop-database ~/.local/share/applications
```

## 2. Remove the old Bash configuration

In `~/.bashrc`, delete `# Custom omarchy configuration` and the custom configuration beneath it.

## 3. Remove the old Hyprland configuration

Delete the legacy Hyprland `.conf` files before installing the new configuration:

```bash
rm -f ~/.config/hypr/{autostart,bindings,envs,hypridle,hyprland-custom,hyprland,input,looknfeel,monitors,hyprlock}.conf
```

## 4. Run the setup script

Run from the repository root:

```bash
./setup.sh && source ~/.bashrc
```

## 5. Configure the monitors

After setup, run `hyprctl monitors all` and configure this machine's monitors using their descriptions, resolutions, refresh rates, scales, layout, and default workspaces.
