#!/usr/bin/env bash

set -euo pipefail

# Installs one add-on from a pinned release archive, replacing its folder.
# Called by setup.sh, which holds the pinned versions, URLs, and checksums.
if (($# != 5)); then
  echo 'Usage: install-pinned-addon.sh GAME_DIR FOLDER VERSION URL SHA256' >&2
  exit 2
fi
if ((EUID == 0)); then
  echo 'Run this script as your normal user, without sudo.' >&2
  exit 1
fi
game_dir=$1
folder=$2
version=$3
url=$4
sha256=$5
if [[ ! -f "$game_dir/Wow.exe" ]]; then
  printf 'WoW not found at %s.\n' "$game_dir" >&2
  exit 1
fi
game_dir=$(realpath -- "$game_dir")

for dependency in curl unzip sha256sum; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf '%s is required but was not found on PATH.\n' "$dependency" >&2
    exit 1
  fi
done

printf '\n==> Installing %s %s (pinned; new releases require a script update)\n' "$folder" "$version"
addons_dir="$game_dir/Interface/AddOns"
mkdir -p -- "$addons_dir"
stage=$(mktemp -d "$addons_dir/.pinned-XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 180 \
  "$url" -o "$stage/download.zip"
if ! printf '%s  %s\n' "$sha256" "$stage/download.zip" | sha256sum --check --status; then
  printf '%s checksum mismatch; existing installation was preserved.\n' "$folder" >&2
  exit 1
fi
unzip -q "$stage/download.zip" -d "$stage/unpacked"
if [[ ! -d "$stage/unpacked/$folder" ]]; then
  printf '%s archive does not contain the %s folder.\n' "$folder" "$folder" >&2
  exit 1
fi
target="$addons_dir/$folder"
if [[ -e $target || -L $target ]]; then
  mv -- "$target" "$stage/previous"
fi
if ! mv -- "$stage/unpacked/$folder" "$target"; then
  if [[ -e "$stage/previous" || -L "$stage/previous" ]]; then
    mv -- "$stage/previous" "$target"
  fi
  exit 1
fi
