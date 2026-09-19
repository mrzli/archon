#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: components/wow-setup/setup.sh [--wow-dir PATH]

Install or update instawow and these Retail WoW addons:
  ALL THE THINGS, BtWQuests, HandyNotes, Deadly Boss Mods, EllesmereUI
  All 12 Zarillion HandyNotes expansion plugins, GatherMate2, GatherMate2_Data
  BtWQuests expansion modules from The Burning Crusade through The War Within,
  plus Battle for Azeroth, Shadowlands, and Dragonflight prologues.
  Midnight is bundled with BtWQuests.

  --wow-dir PATH  Path to the _retail_ directory. Defaults to the Omarchy
                  Battle.net installation under ~/Games/battlenet.
  -h, --help     Show this help.

Requires uv on PATH. Close WoW before running. Run without sudo.
instawow is installed into ~/.local/bin. Addons use instawow's wow-retail
profile. Unrelated addons and WoW settings are preserved. Existing addons
not managed by this profile are not automatically overwritten.
After installing GatherMate2_Data, use GatherMate2's in-game Import settings
to select databases and import them with Merge to preserve discovered nodes.
EOF
}

wow_dir="$HOME/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_retail_"
while (($#)); do
  case "$1" in
    --wow-dir)
      if (($# < 2)) || [[ -z $2 ]]; then
        echo '--wow-dir requires a path to the _retail_ directory.' >&2
        exit 2
      fi
      wow_dir=$2
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if ((EUID == 0)); then
  echo 'Run this script as your normal user, without sudo.' >&2
  exit 1
fi
if ! command -v uv >/dev/null 2>&1; then
  echo 'uv is required but was not found on PATH.' >&2
  exit 1
fi
if [[ ! -f "$wow_dir/Wow.exe" ]]; then
  printf 'Retail WoW not found at %s. Use --wow-dir PATH.\n' "$wow_dir" >&2
  exit 1
fi
wow_dir=$(realpath -- "$wow_dir")

printf '\n==> Installing or updating instawow\n'
export UV_TOOL_BIN_DIR="$HOME/.local/bin"
uv tool install --upgrade instawow
instawow=("$HOME/.local/bin/instawow" --no-cache -v -p wow-retail)

printf '\n==> Configuring Retail WoW addons\n'
mkdir -p -- "$wow_dir/Interface/AddOns"
"${instawow[@]}" configure "addon_dir=$wow_dir/Interface/AddOns" flavour_override=retail

# Author release archives on GitHub and WoWInterface require no CurseForge key.
addons=(
  github:ATTWoWAddon/AllTheThings
  wowi:24680 # BtWQuests
  wowi:25631 # BtWQuests: The Burning Crusade
  wowi:25784 # BtWQuests: Wrath of the Lich King
  wowi:25552 # BtWQuests: Cataclysm (includes old-world zones)
  wowi:25547 # BtWQuests: Mists of Pandaria
  wowi:25553 # BtWQuests: Warlords of Draenor
  wowi:24770 # BtWQuests: Legion
  wowi:25792 # BtWQuests: Battle for Azeroth
  wowi:25655 # BtWQuests: Shadowlands
  wowi:26399 # BtWQuests: Dragonflight
  wowi:26776 # BtWQuests: The War Within
  wowi:24769 # BtWQuests: Battle for Azeroth Prologue
  wowi:25660 # BtWQuests: Shadowlands Prologue
  wowi:26458 # BtWQuests: Dragonflight Prologue
  github:Nevcairiel/HandyNotes
  # Individual author-published packages avoid GitHub's multi-archive ambiguity.
  wowi:26818 # HandyNotes: Kalimdor & Eastern Kingdoms (Zarillion)
  wowi:26817 # HandyNotes: The Burning Crusade
  wowi:26816 # HandyNotes: Wrath of the Lich King
  wowi:26815 # HandyNotes: Cataclysm
  wowi:26814 # HandyNotes: Mists of Pandaria
  wowi:26813 # HandyNotes: Warlords of Draenor
  wowi:26812 # HandyNotes: Legion
  wowi:25829 # HandyNotes: Battle for Azeroth
  wowi:25828 # HandyNotes: Shadowlands
  wowi:26409 # HandyNotes: Dragonflight
  wowi:26753 # HandyNotes: The War Within
  wowi:27067 # HandyNotes: Midnight (Zarillion)
  github:Nevcairiel/GatherMate2
  github:Nevcairiel/GatherMate2_Data
  github:DeadlyBossMods/DeadlyBossMods
  github:EllesmereGaming/EllesmereUI
)

printf '\n==> Installing or updating addons\n'
for addon in "${addons[@]}"; do
  installed=$("${instawow[@]}" list --format simple "$addon")
  if [[ -z $installed ]]; then
    "${instawow[@]}" install "$addon"
  fi
done
# Updating the profile treats already-current addons as success; named updates do not.
"${instawow[@]}" update

printf '\nAddons are ready. Start WoW and check the AddOns menu.\n'
printf 'For preloaded gathering nodes, open GatherMate2 settings > Import and use Merge.\n'
