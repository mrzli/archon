# Archon

My [Omarchy](https://omarchy.org/) development workstation, defined as code.

Every change to my workstation starts here, whether it is the software I install, its configuration, or how my tooling and processes work. The repository is the source of truth, and the workstation follows it.

## How it works

I update this repository, or ask an AI agent to update it, and then run [`setup.sh`](setup.sh), the setup script that is part of this repository. It brings my workstation to the state the repository describes. In most cases, that takes a few seconds.

Updating is idempotent. Running it once or many times gives the same result, so I can run it at any time without being careful, and a repeated run does no harm.

## Why

I used to hate setting up a computer. Reinstalling meant a long, tedious job of installing every tool and recreating every setting by hand, so the thought of formatting a drive was a nightmare. I wanted that process to be painless, and now it is trivial.

The repository is a complete record of how my workstation should be set up. My code and data are online as well, so if a computer breaks, gets lost, or needs a reinstall, I lose nothing important, and a new workstation is running within several minutes.

For the same reason, moving between computers is easy. I work on more than one at the same time. When I switch, I pull this repository and run the setup script, and a few seconds later that computer is set up exactly as I want.

## What I get from it

- **The same environment on every machine.** Applications, developer tools, editor settings, keybindings, and shell configuration match everywhere. A new machine needs only a short installation and one run of the setup script.
- **All my projects in one structure.** My repositories, across my GitHub account and organizations, live under `~/projects/personal/<owner>/<repository>`. `arc projects sync` clones the missing ones and updates the rest, and `arc projects status` shows which of them have uncommitted or unpushed work.
- **Project workspaces in a terminal multiplexer.** `arc workspaces herdr start` opens the projects I choose in Herdr, the multiplexer I currently use, and the same command works with tmux. Each project gets tabs for Neovim, lazygit, a shell, and an AI coding agent that resumes its last conversation. Archon remembers which projects I chose.
- **Voice dictation.** Setup installs Voxtype with a local Whisper model that runs on the GPU. I use it to dictate my prompts to AI agents.
- **AI agents set up the same way everywhere.** Setup installs my [agent skills](https://github.com/mrzli/skills) and my [global agent instructions](data/home/.codex/AGENTS.md), which both Claude Code and Codex read. `arc agents reload` runs setup and restarts every running agent session, so the sessions pick up the change.

## Setup

`setup.sh`, or `arc setup` once the CLI is installed:

- installs applications, packages, language runtimes, and developer tools, and removes Omarchy defaults I don't use
- copies my configuration files into the home directory, such as Hyprland, Neovim, Bash, Git, VS Code, Claude Code, and Codex settings
- installs the Archon CLI and my agent skills
- sets up rootless Docker and voice dictation

## Installing a new machine

A new machine needs a one-time installation: write the Omarchy ISO to a USB stick, install Omarchy, clone this repository, and run the setup script. A few manual steps follow, such as connecting to Wi-Fi, signing in to browser accounts, and adding the GitHub SSH key. I left them manual on purpose, and they take about five minutes. The [installation guide](docs/installation.md) has the details.

## Archon CLI

`archon`, or its short alias `arc`, provides the commands above and a few more, such as for drives, battery charging, voice dictation, and GitHub SSH keys. The [CLI documentation](components/archon-cli/README.md) describes every command.

## License

[MIT](LICENSE)
