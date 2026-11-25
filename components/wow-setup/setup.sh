#!/usr/bin/env bash

set -euo pipefail

# Before running this script for the user, mention the pinned add-on limitation:
# Auctionator and BugGrabber use fixed CurseForge CDN URLs; they cannot discover
# updates themselves. Newer releases require manually updating the version, URL,
# and SHA-256 in the pins below. Check
# https://www.curseforge.com/wow/addons/auctionator/files and
# https://www.curseforge.com/wow/addons/bug-grabber/files for the latest
# releases and tell the user whether the pinned versions have been checked.

usage() {
  cat <<'EOF'
Usage: components/wow-setup/setup.sh [--retail-dir PATH] [--forever-dir PATH]

Install or update instawow and the add-ons for each installed game.

Retail add-ons:
  ALL THE THINGS, BtWQuests, HandyNotes, Deadly Boss Mods, EllesmereUI
  All 12 Zarillion HandyNotes expansion plugins, GatherMate2, GatherMate2_Data
  Auctionator (fixed release; newer versions require a script update)
  BtWQuests expansion modules from The Burning Crusade through The War Within,
  plus Battle for Azeroth, Shadowlands, and Dragonflight prologues.
  Midnight is bundled with BtWQuests.

WoW Forever add-ons:
  Questie (with QuestieTrace), HandyNotes, HandyNotes: WoW Forever,
  GatherMate2, Deadly Boss Mods with its Forever raid and dungeon modules,
  EllesmereUI, BugSack
  Auctionator and BugGrabber (fixed releases; newer versions require a
  script update)

  --retail-dir PATH   Path to the _retail_ directory.
  --forever-dir PATH  Path to the _forever_ directory.
  -h, --help          Show this help.

Each directory defaults to the Omarchy Battle.net installation under
~/Games/battlenet. A game whose default directory is missing is skipped; a
directory given as an option must exist. At least one game must be found.

Requires uv, ruby, curl, unzip, and sha256sum on PATH. Close WoW before
running. Run without sudo, in a terminal.
When instawow has no GitHub login saved, the script starts instawow's GitHub
login once, which you approve in the browser. Without it, GitHub allows 60
requests an hour, and a first run for both games can stop partway; running
again later continues.
instawow is installed into ~/.local/bin. Add-ons use instawow's wow-retail and
wow-forever profiles. Unrelated add-ons and WoW settings are preserved.
Existing add-ons not managed by these profiles are not automatically
overwritten, except the pinned ones: their folders are replaced with the pinned
releases; saved settings are preserved.
After installing GatherMate2_Data in Retail, use GatherMate2's in-game Import
settings to select databases and import them with Merge to preserve discovered
nodes.
EOF
}

wow_root="$HOME/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft"
retail_dir="$wow_root/_retail_"
forever_dir="$wow_root/_forever_"
retail_required=false
forever_required=false
while (($#)); do
  case "$1" in
    --retail-dir|--forever-dir)
      if (($# < 2)) || [[ -z $2 ]]; then
        printf '%s requires a path.\n' "$1" >&2
        exit 2
      fi
      if [[ $1 == --retail-dir ]]; then
        retail_dir=$2
        retail_required=true
      else
        forever_dir=$2
        forever_required=true
      fi
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

# Prints the resolved game directory, or nothing when an optional game is absent.
find_game() {
  local name=$1 dir=$2 required=$3
  if [[ -f "$dir/Wow.exe" ]]; then
    realpath -- "$dir"
  elif [[ $required == true ]]; then
    printf '%s not found at %s.\n' "$name" "$dir" >&2
    return 1
  else
    printf '%s not found at %s; skipping it.\n' "$name" "$dir" >&2
  fi
}
retail_dir=$(find_game 'Retail WoW' "$retail_dir" "$retail_required")
forever_dir=$(find_game 'WoW Forever' "$forever_dir" "$forever_required")
if [[ -z $retail_dir && -z $forever_dir ]]; then
  echo 'No WoW installation found. Use --retail-dir or --forever-dir.' >&2
  exit 1
fi

printf '\n==> Installing or updating instawow\n'
export UV_TOOL_BIN_DIR="$HOME/.local/bin"
uv tool install --upgrade instawow
instawow() {
  "$HOME/.local/bin/instawow" --no-cache -v "$@"
}

component_dir=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")

# Pinned add-ons that instawow cannot install without a CurseForge key:
# folder, version, URL, and SHA-256.
auctionator=(Auctionator 339
  https://edge.forgecdn.net/files/8939/586/Auctionator-339.zip
  773e93d95249eb3988c79c65721476b57cf91ea0fdba8fe1c728b4f88212d6b2)
buggrabber=('!BugGrabber' v12.1.1
  'https://edge.forgecdn.net/files/9277/326/%21BugGrabber-v12.1.1.zip'
  1e53e65c72f525a45c8951abe06415df5b1fb52ec21e30970c1416a2fbd4a250)

# Prints "saved" or "missing" for instawow's GitHub login. instawow documents
# no way to check for a saved token, so this relies on the undocumented JSON
# layout of `instawow debug` for a configured profile, which shows a saved
# token masked and a missing one as null. It stops with an error when that
# layout changes, rather than guessing.
# Takes the name of a configured profile.
github_login_state() {
  # shellcheck disable=SC2016 # The Ruby program expands its own variables.
  instawow -p "$1" debug | ruby -rjson -e '
    error = "Cannot read the GitHub login from instawow debug output; update setup.sh for this instawow version."
    begin
      tokens = JSON.parse($stdin.read).dig("active_profile_config", "global_config", "access_tokens")
    rescue JSON::ParserError, TypeError, NoMethodError
      abort error
    end
    abort error unless tokens.is_a?(Hash) && tokens.key?("github")
    case tokens["github"]
    when nil then puts "missing"
    when String then puts "saved"
    else abort error
    end
  '
}

# Without a GitHub login, instawow is limited to 60 GitHub API requests an
# hour, which a first run for both games can exceed. The login is global to
# instawow, so it is offered once per run, through one configured profile.
ensure_github_login() {
  local profile=$1 state
  state=$(github_login_state "$profile")
  if [[ $state == saved ]]; then
    return
  fi
  if [[ ! -t 0 ]]; then
    echo 'No GitHub login saved for instawow. Run this script in a terminal to log in.' >&2
    return
  fi
  printf '\n==> Logging instawow in to GitHub\n'
  instawow -p "$profile" configure global_config.access_tokens.github
}

# Points one game's profile at the game's add-on folder.
configure_profile() {
  local game_dir=$1 profile=$2 flavour=$3
  mkdir -p -- "$game_dir/Interface/AddOns"
  instawow -p "$profile" configure "addon_dir=$game_dir/Interface/AddOns" "flavour_override=$flavour"
}

# Installs missing add-ons into one game's profile, then updates the profile.
install_addons() {
  local profile=$1 addon installed
  shift
  for addon in "$@"; do
    installed=$(instawow -p "$profile" list --format simple "$addon")
    if [[ -z $installed ]]; then
      instawow -p "$profile" install "$addon"
    fi
  done
  # Updating the profile treats already-current addons as success; named updates do not.
  instawow -p "$profile" update
}

# Author release archives on GitHub and WoWInterface require no CurseForge key.
retail_addons=(
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

forever_addons=(
  github:Questie/Questie # Includes QuestieTrace.
  github:Nevcairiel/HandyNotes
  github:kemayo/wow-handynotes-forever # HandyNotes: WoW Forever
  github:Nevcairiel/GatherMate2
  github:DeadlyBossMods/DeadlyBossMods
  github:DeadlyBossMods/DBM-Vanilla # Forever raids
  github:DeadlyBossMods/DBM-Dungeons # Forever dungeons
  github:EllesmereGaming/EllesmereUI
  github:funkydude/BugSack # Requires the pinned BugGrabber.
)

# The GitHub login needs a configured profile, so profiles are configured first.
login_profile=
if [[ -n $retail_dir ]]; then
  configure_profile "$retail_dir" wow-retail retail
  login_profile=wow-retail
fi
if [[ -n $forever_dir ]]; then
  configure_profile "$forever_dir" wow-forever forever_classic
  login_profile=${login_profile:-wow-forever}
fi
ensure_github_login "$login_profile"

if [[ -n $retail_dir ]]; then
  printf '\n==> Installing or updating Retail WoW add-ons\n'
  install_addons wow-retail "${retail_addons[@]}"
  bash "$component_dir/install-pinned-addon.sh" "$retail_dir" "${auctionator[@]}"
fi

if [[ -n $forever_dir ]]; then
  printf '\n==> Installing or updating WoW Forever add-ons\n'
  install_addons wow-forever "${forever_addons[@]}"
  bash "$component_dir/install-pinned-addon.sh" "$forever_dir" "${auctionator[@]}"
  bash "$component_dir/install-pinned-addon.sh" "$forever_dir" "${buggrabber[@]}"
fi

printf '\nAdd-ons are ready. Start WoW and check the AddOns menu.\n'
if [[ -n $retail_dir ]]; then
  printf 'For preloaded Retail gathering nodes, open GatherMate2 settings > Import and use Merge.\n'
fi
