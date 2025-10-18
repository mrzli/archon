```
# INSTALL VIA PACMAN
- zsh               - Z shell.
- git               - Version control system.
- hyprland          - Wayland compositor/VM.
- alacritty         - Terminal emulator.
- ttf-firacode-nerd - Fira Code Nerdfont.
- adwaita-cursors   - Standard GNOME cursors.
- mise              - Version manager.
- rust              - Rust programming language. Required for 'paru', which won't work with rust installed via mise.
```

```
chsh -s /bin/zsh    # Change default shell to zsh, requires logout/login.
```

NOTE:
- make sure mise is active in zshrc (see config)

```
# SETUP USING MISE:
mise install rust
mise use -g rust      # Seems to update .config/mise/config.toml, may not be necessary if config is copied from here.
```

```
# INSTALL VIA RUN SCRIPTS:
# before all, navigate to "$XDG_DATA_HOME/machine-setup/run"
./run paru-install  # Install paru AUR helper.
```

```
paru -S --noconfirm google-chrome
```

```
