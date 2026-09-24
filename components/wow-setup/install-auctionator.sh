#!/usr/bin/env bash

set -euo pipefail

# Called by setup.sh with the Retail WoW directory as its only argument.
# Pinned release: update the version, URL, and SHA-256 together after checking
# https://www.curseforge.com/wow/addons/auctionator/files for a new Retail release.
if (($# != 1)); then
  echo 'Usage: install-auctionator.sh PATH_TO_RETAIL' >&2
  exit 2
fi
if ((EUID == 0)); then
  echo 'Run this script as your normal user, without sudo.' >&2
  exit 1
fi
wow_dir=$1
if [[ ! -f "$wow_dir/Wow.exe" ]]; then
  printf 'Retail WoW not found at %s.\n' "$wow_dir" >&2
  exit 1
fi
wow_dir=$(realpath -- "$wow_dir")

for dependency in curl unzip sha256sum; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf '%s is required but was not found on PATH.\n' "$dependency" >&2
    exit 1
  fi
done

auctionator_version=339
auctionator_url="https://edge.forgecdn.net/files/8939/586/Auctionator-${auctionator_version}.zip"
auctionator_sha256=773e93d95249eb3988c79c65721476b57cf91ea0fdba8fe1c728b4f88212d6b2
printf '\nAuctionator is pinned to version %s. New releases require a manual script update.\n' "$auctionator_version"

mkdir -p -- "$wow_dir/Interface/AddOns"
printf '\n==> Installing Auctionator %s\n' "$auctionator_version"
auctionator_stage=$(mktemp -d "$wow_dir/Interface/AddOns/.auctionator-XXXXXXXX")
trap 'rm -rf -- "$auctionator_stage"' EXIT
curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 180 \
  "$auctionator_url" -o "$auctionator_stage/download.zip"
if ! printf '%s  %s\n' "$auctionator_sha256" "$auctionator_stage/download.zip" | sha256sum --check --status; then
  echo 'Auctionator checksum mismatch; existing installation was preserved.' >&2
  exit 1
fi
unzip -q "$auctionator_stage/download.zip" -d "$auctionator_stage/unpacked"
[[ -d "$auctionator_stage/unpacked/Auctionator" ]]
auctionator_dir="$wow_dir/Interface/AddOns/Auctionator"
if [[ -e $auctionator_dir || -L $auctionator_dir ]]; then
  mv -- "$auctionator_dir" "$auctionator_stage/previous"
fi
if ! mv -- "$auctionator_stage/unpacked/Auctionator" "$auctionator_dir"; then
  if [[ -e "$auctionator_stage/previous" || -L "$auctionator_stage/previous" ]]; then
    mv -- "$auctionator_stage/previous" "$auctionator_dir"
  fi
  exit 1
fi

