# Setup

## Hardware Installation

### Bluetooth

Install packages using pacman:

```bash
pacman -S --noconfirm <package-name>
```

```
- bluez             - Bluetooth protocol stack.
- bluez-utils       - Command-line tools for Bluetooth.
- bluetui           - Terminal user interface for managing Bluetooth devices.
```

Start and enable the Bluetooth service:

```bash
sudo systemctl enable --now bluetooth.service
```

### Sound

How does playing sound work?

1. Applications want to play sound or record audio.
    1. Some apps talk to PipeWire directly.
        - Examples:
            - Media players like mpv can use PipeWire directly.
    2. Most apps talk to PulseAudio, which then talks to PipeWire.
        - Examples:
            - Web browsers like Firefox and Chrome use PulseAudio.
            - Communication apps like Discord and Zoom use PulseAudio.
    3. Some apps, mostly professional audio software, use JACK, which then talks to PipeWire.
        - Examples:
            - Digital Audio Workstations (DAWs) like Ardour use JACK.
2. PipeWire then sends the audio to the sound hardware, using something like wireplumber to manage the connections.
3. This gets translated to make a call to the actual sound hardware via ALSA (Advanced Linux Sound Architecture), using pipewire-alsa.
4. ALSA is the low-level interface that directly communicates with the sound card.

How does microphone input work?

1. Sound hardware captures audio input from all connected microphones, sending it to ALSA.  
2. ALSA passes the audio input to pipewire-alsa.
3. wireplumber manages the audio input devices and routes the audio to PipeWire.
4. PipeWire then makes the audio input available to applications, either directly or through PulseAudio or JACK.

Flowchart:

- Sound flow:  
  App --> (PulseAudio/JACK/Direct) --> PipeWire --> wireplumber --> pipewire-alsa --> ALSA --> Sound Hardware
- Microphone flow:  
  Sound Hardware --> ALSA --> pipewire-alsa -- wireplumber --> PipeWire --> (PulseAudio/JACK/Direct) --> App

Install packages using pacman:

```bash
pacman -S --noconfirm <package-name>
```

```
- pipewire          - Sound server/processor, central to audio handling.
- pipewire-alsa     - Allows communication between PipeWire and ALSA.
- pipewire-jack     - Allows communication between apps using JACK and PipeWire.
- pipewire-pulse    - Allows communication between apps using PulseAudio and PipeWire.
- wireplumber       - Discovers and manages audio devices for PipeWire.
```

Start services with:

```bash
systemctl --user enable --now pipewire wireplumber pipewire-pulse
# This updates ~/.config/systemd/user/ files. If you remove that config, you may need to run this command again.
```

Log out and back in to ensure services start properly, or reboot the system.

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
- waybar            - Status bar for Wayland.
- walker            - Application launcher.
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

