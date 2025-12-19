# Archon

A set of scripts to set up a new Arch Linux installation.

A lot of it is based on, copied from, or inspired by [Omarchy](https://github.com/basecamp/omarchy).

## Clone This Repository

To clone this repository, run the following command in your terminal:

```bash
curl -sSL https://raw.githubusercontent.com/mrzli/archon/master/repo.sh | bash
```

To remove the cloned repository:

```bash
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share} rm -rf "$XDG_DATA_HOME/archon"
```

## Install Arch Linux

```bash
python ~/.local/share/archon/setup/arch_install.py
```

## Setup Arch Linux

### Setup System

```bash
python ~/.local/share/archon/setup/setup.py i
python ~/.local/share/archon/setup/setup.py c
```

Change shell to zsh:

```bash
chsh -s /bin/zsh
```

Re login to see changes.

### Remove Setup

```bash
python ~/.local/share/archon/setup/setup.py u
```

## Other

Generate font here: https://patorjk.com/software/taag/#p=display&f=Delta+Corps+Priest+1

## License

Archon is released under the [MIT License](https://opensource.org/licenses/MIT).
