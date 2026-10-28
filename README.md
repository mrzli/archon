# Archon

This repository represents the setup of my development workstation.

When I need to change my system, such as what I have installed or how my
tooling and processes are set up, this is where I make the change. Running the
setup script applies it, usually within a few seconds. Running the same script
on another Omarchy computer gives it the same setup.

Archon also includes a command-line program for my daily work across many
repositories and AI coding agents, and it manages my global instructions for
those agents.

## Setup

`setup.sh`, or `arc setup` once the CLI is installed, applies my configuration:

- installs applications, packages, language runtimes, and developer tools, and
  removes Omarchy defaults I don't use
- copies my configuration files into the home directory, such as Hyprland,
  Neovim, Bash, Git, VS Code, Claude Code, and Codex settings
- installs the Archon CLI and my agent skills
- sets up rootless Docker and voice dictation

Setup is idempotent, so I can run it as often as I like. A run on a configured
machine takes a few seconds, and a run that installs new software takes longer.

## Installing a new machine

A new machine needs a one-time installation: write the Omarchy ISO to a USB
stick, install Omarchy, clone this repository, and run setup. A few manual
steps follow, such as connecting to Wi-Fi, signing in to browser accounts, and
adding the GitHub SSH key. I left them manual on purpose, and they take about
five minutes. The [installation guide](docs/installation.md) has the details.

## Archon CLI

`archon`, or its short alias `arc`, handles daily work on the machine. The most
important commands:

- `arc workspaces <herdr|tmux|visual-studio-code> start` opens the projects I
  choose. Each terminal project gets tabs for Neovim, lazygit, a shell, and an
  AI agent that resumes its last conversation.
- `arc projects sync` clones or updates all my repositories from GitHub, and
  `arc projects status` shows which of them have uncommitted or unpushed work.
- `arc agents reload` runs setup and then restarts every running Claude Code
  and Codex session, so they pick up new skills, instructions, and settings.

The [CLI documentation](components/archon-cli/README.md) describes every
command.

## Agent instructions

Archon also manages my global instructions for AI coding agents in
[`data/home/.codex/AGENTS.md`](data/home/.codex/AGENTS.md), which both Claude
Code and Codex read. My agent skills are in the
[skills repository](https://github.com/mrzli/skills), and setup installs them.

## License

[MIT](LICENSE)
