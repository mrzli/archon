```
pacman -S --noconfirm <package-name>
# INSTALL VIA PACMAN
- zsh               - Z shell.
- git               - Version control system.
- alacritty         - Terminal emulator.
- ttf-firacode-nerd - Fira Code Nerdfont.
- adwaita-cursors   - Standard GNOME cursors.
- mise              - Version manager.
- rustup            - Rust toolchain installer.
- jq                - Command-line JSON processor.
- starship          - Shell prompt.
- hyprland          - Wayland compositor/VM.
```

NOTE:
- Default hyprland config: https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.conf

```
chsh -s /bin/zsh    # Change default shell to zsh, requires logout/login.
```

```
# for rustup:
rustup default stable
# see config, maybe it can be copied directly
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
paru -S --noconfirm <package-name>
# INSTALL VIA PARU:
- zsh-vi-mode          - Vi keybindings for zsh.
- google-chrome        - Web browser.
```

