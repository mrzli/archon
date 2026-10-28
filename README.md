# Archon

My [Omarchy](https://omarchy.org/) development workstation, defined as code.

Every change to my workstation starts here, whether it is the software I install, its configuration, or how my tooling and processes work. The repository is the source of truth, and the workstation follows it.

## Overview

### How it works

I update this repository, or ask an AI agent to update it, and then run [`setup.sh`](setup.sh), the setup script that is part of this repository. It brings my workstation to the state the repository describes. In most cases, that takes a few seconds.

Updating is idempotent. Running it once or many times gives the same result, so I can run it whenever I want, without a second thought.

### Why

I used to hate setting up a computer. Reinstalling meant a long, tedious job of installing every tool and recreating every setting by hand, so the thought of formatting a drive was a nightmare. I wanted that process to be painless, and now it is trivial.

The repository is a complete record of how my workstation should be set up. My code and data are online as well, so if a computer breaks, gets lost, or needs a reinstall, I lose nothing important, and a new workstation is running within several minutes.

For the same reason, moving between computers is easy. I work on more than one at the same time. When I switch, I pull this repository and run the setup script, and a few seconds later that computer is set up exactly as I want.

### What I get from it

- **The same environment on every machine.** Applications, developer tools, editor settings, keybindings, and shell configuration match everywhere. A new machine needs only a short installation and one run of the setup script.
- **Development tools ready to use.** Setup installs the language runtimes and developer tools I use, such as Node.js, Python, Ruby, Go, and Claude Code, mostly through mise. VS Code comes with all my extensions, settings, keybindings, and snippets.
- **All my projects in one place.** My repositories live in one fixed structure, one command keeps all of them in sync, and their secrets are kept in one store. See [Projects](#projects).
- **Project workspaces in a terminal multiplexer.** One command opens the projects I'm working on, each with my editor, Git client, shell, and AI agent ready. See [Workspaces](#workspaces).
- **Voice dictation.** Setup installs Voxtype with a local Whisper model that runs on the GPU. I use it to dictate my prompts to AI agents.
- **AI agents set up the same way everywhere.** Setup installs my [agent skills](https://github.com/mrzli/skills) and my [global agent instructions](data/home/.codex/AGENTS.md), which both Claude Code and Codex read. When I change a skill, the global instructions, or another agent setting, `arc agents reload` runs setup and restarts every running agent session, so all of them pick up the change at once.

## Features

### Setup

`setup.sh`, or `arc setup` once the CLI is installed, does the following:

- Installs applications, packages, language runtimes, and developer tools, and removes Omarchy defaults I don't use.
- Copies my configuration files into the home directory, such as Hyprland, Neovim, Bash, Git, VS Code, Claude Code, and Codex settings.
- Installs the Archon CLI and my agent skills.
- Sets up rootless Docker and voice dictation.

### Projects

All my repositories live in one fixed structure, `~/projects/personal/<owner>/<repository>`, where the owner is my GitHub account or one of my organizations. Repositories I clone from other people go directly under `~/projects/cloned`. Because the structure is fixed, the Archon CLI can manage every project at once:

- `arc projects sync` clones the repositories that are on GitHub but missing locally, and fast-forwards the ones that are clean. A new machine gets all my projects with one command.
- `arc projects status` shows each repository's branch state, uncommitted changes, stashes, and unpushed commits, so I can see at a glance where work is left.
- `arc projects prune` deletes local repositories that no longer exist on GitHub, after listing them and asking for confirmation.
- `arc projects secrets` keeps secret values, such as API tokens, in one local store, and generates each project's `.env` file from a template committed in that project. A token I use in several projects is stored only once.

The workspace commands use the same structure, so I can open any project in Herdr, tmux, or VS Code.

### Workspaces

A workspace opens the projects I choose, ready to work in. Projects gives me every repository on the machine, and Workspaces opens the ones I'm working on.

`arc workspaces <backend> start` shows a checklist of every project in the fixed structure, and opens the ones I select. The backend is Herdr, the terminal multiplexer I currently use, tmux, or VS Code, and I always name it, since there is no default. Each backend remembers its own selection, so next time the same projects are already checked. New projects start unchecked.

In Herdr and tmux, each project gets tabs for Neovim, lazygit, a shell, and an AI coding agent. The agent is Claude Code by default and resumes the project's last conversation, or starts a new one if there is none. With `--ai codex`, it is Codex instead. Starting again keeps workspaces that are already open, and `stop` and `kill` close them.

In VS Code, each selected project opens in its own window, on a Hyprland workspace I choose.

### Other commands

`archon`, or its short alias `arc`, provides the commands above and a few more, such as for drives, battery charging, voice dictation, and GitHub SSH keys. The [CLI documentation](components/archon-cli/README.md) describes every command.

## Installation

### Installing a new machine

A new machine needs a one-time installation: write the Omarchy ISO to a USB stick, install Omarchy, clone this repository, and run the setup script. A few manual steps follow, such as connecting to Wi-Fi, signing in to browser accounts, and adding the GitHub SSH key. I left them manual on purpose. They could probably be automated too, but they take only a few minutes, so automating them is not worth the effort yet. The [installation guide](docs/installation.md) has the details.

## License

[MIT](LICENSE)
