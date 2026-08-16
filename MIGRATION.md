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

## 3. Run the setup script

Run from the repository root:

```bash
./setup.sh && source ~/.bashrc
```
