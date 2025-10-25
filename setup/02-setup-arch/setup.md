# Setup

## Install From Standard Repositories

```bash
pacman -S --noconfirm <package-name>
```

```
# ESSENTIALS:
- git               - Version control system.

# FONTS AND THEMES:
- adwaita-cursors   - Standard GNOME cursors.
- ttf-firacode-nerd - Fira Code Nerdfont.

# SHELL:
- jq                - Command-line JSON processor.
- starship          - Shell prompt.
- zsh               - Z shell.

# APPLICATIONS:
- alacritty         - Terminal emulator.
- neovim            - Text editor.

# DEVELOPMENT:
- mise              - Version manager.
- rustup            - Rust toolchain installer.

# UI:
- hyprland          - Wayland compositor/VM.
```

## Rest

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

