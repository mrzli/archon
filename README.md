# Archon

This repository is the setup of my [Omarchy](https://omarchy.org/) development workstation.

When I change what I want installed, or how I want my tooling and processes to be set up, this is where I make the change here.

This is the source of truth. It is essentially setup as a code <todo is this the proper expression ?>.

## How does it work?

I update the repository or ask the agent to update it. Then I run the setup script.

This produces the <situation on my workstation>. In most cases, it takes just a few seconds.

The setup is idempotent. I can run it once or many times, and the result is the same. It will sync my workstation to <this repo>, and nothing more.

## Why?

<I don't know whether that's the best wording but please rephrase it but essentially this is a declarative record of my setup of my system slash workstation setup>

if I ever need to delete my computer or reinstall it like all of the important stuff is online I have essentially nothing that I will lose if I lose the computer if I whatever right and also mentioned the fact that I'm working on multiple computers at the same time so I can just move to another computer and a few seconds later have the entire setup exactly as I want it usually a few seconds later


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

A run that installs new software takes longer than the usual few seconds.

## Installing a new machine

A new machine needs a one-time installation: write the Omarchy ISO to a USB stick, install Omarchy, clone this repository, and run the setup script. A few manual steps follow, such as connecting to Wi-Fi, signing in to browser accounts, and adding the GitHub SSH key. I left them manual on purpose, and they take about five minutes. The [installation guide](docs/installation.md) has the details.

## Archon CLI

`archon`, or its short alias `arc`, provides the commands above and a few more, such as for drives, battery charging, voice dictation, and GitHub SSH keys. The [CLI documentation](components/archon-cli/README.md) describes every command.

## License

[MIT](LICENSE)
