#!/usr/bin/env bash
# Guides the user through writing an Omarchy ISO to a USB drive.
# Depends only on tools found on a standard Linux system, so it can also run
# on a computer without Archon.

set -euo pipefail

readonly SITE_URL='https://omarchy.org/'
readonly ISO_HOST='https://iso.omarchy.org'
readonly DOWNLOAD_DIR="$HOME/Downloads"
readonly DRIVE_COLUMNS='NAME,TYPE,RM,TRAN,SIZE,MODEL,SERIAL'

# Runs as a single sudo call, so the credential cannot expire between writing
# and checking. Its exit statuses tell the caller which step failed.
# shellcheck disable=SC2016 # The root shell expands these variables.
readonly WRITE_AND_CHECK='
  iso=$1 device=$2 size=$3 size_text=$4
  printf "\nWriting %s. This can take several minutes...\n" "$size_text"
  dd if="$iso" of="$device" bs=4M conv=fsync,nocreat oflag=direct status=progress || exit 10
  printf "\nChecking the %s that were written...\n" "$size_text"
  dd if="$device" bs=4M iflag=count_bytes count="$size" status=progress | cmp - "$iso"
  statuses=("${PIPESTATUS[@]}")
  (( statuses[0] == 0 || statuses[0] == 141 )) || exit 11
  (( statuses[1] == 0 )) || exit 12
'

die() {
  printf '\nError: %s\n' "$*" >&2
  exit 1
}

cancel() {
  printf '\nCanceled. Nothing was written.\n'
  exit 1
}

check_tools() {
  local tool missing=()
  for tool in cmp curl dd grep lsblk sed sha256sum sort stat sudo tr; do
    command -v "$tool" > /dev/null 2>&1 || missing+=("$tool")
  done
  if (( ${#missing[@]} > 0 )); then
    die "Install these tools and run again: ${missing[*]}"
  fi
  lsblk -no MOUNTPOINTS > /dev/null 2>&1 ||
    die "This lsblk is too old. Update util-linux to version 2.37 or later and run again."
}

# Sets answer. End of input cancels, so it can never count as a confirmation.
ask() {
  printf '%s' "$1"
  IFS= read -r answer || cancel
}

# Sets choice to the 1-based position of the selected option.
# A default of 0 means the user must enter a number.
choose() {
  local title=$1 default=$2 index prompt='Choose: '
  shift 2
  printf '\n%s\n' "$title"
  for (( index = 1; index <= $#; index++ )); do
    printf '  %d) %s\n' "$index" "${!index}"
  done
  (( default > 0 )) && prompt="Choose [$default]: "
  while true; do
    ask "$prompt"
    [[ -z $answer ]] && (( default > 0 )) && answer=$default
    if [[ $answer =~ ^[0-9]+$ ]] && (( 10#$answer >= 1 && 10#$answer <= $# )); then
      choice=$(( 10#$answer ))
      return
    fi
    printf 'Enter a number from 1 to %d.\n' "$#"
  done
}

# Prints the first ISO name for an architecture found on the Omarchy website,
# or nothing when the page lists none.
iso_name_on_site() {
  { grep -oE "omarchy-[0-9][^\"'<> /]*-$2\.iso" <<< "$1" || true; } | sed -n 1p
}

# Prints the published checksum, or fails when there is no usable one.
published_checksum() {
  local checksum
  checksum=$(curl -fsSL "$ISO_HOST/$1.sha256" 2> /dev/null) || return 1
  checksum=${checksum%%[[:space:]]*}
  [[ $checksum =~ ^[0-9a-fA-F]{64}$ ]] || return 1
  printf '%s' "${checksum,,}"
}

matches_checksum() {
  local actual
  printf 'Verifying the checksum of %s...\n' "${1##*/}"
  actual=$(sha256sum "$1")
  [[ ${actual%%[[:space:]]*} == "$2" ]]
}

# Sets iso_path to the verified ISO, downloading it unless it is already there.
obtain_latest_iso() {
  local name=$1 path="$DOWNLOAD_DIR/$1" part="$DOWNLOAD_DIR/$1.part" checksum
  checksum=$(published_checksum "$name") || die "Could not get the published checksum of $name."
  mkdir -p "$DOWNLOAD_DIR"

  if [[ -f $path ]]; then
    printf '\nFound %s.\n' "$path"
    matches_checksum "$path" "$checksum" ||
      die "$path does not match the published checksum. Delete it and run this script again."
  else
    printf '\nDownloading %s...\n' "$name"
    if ! curl -fL -o "$part" "$ISO_HOST/$name"; then
      rm -f -- "$part"
      die "The download failed. Run this script again to retry."
    fi
    if ! matches_checksum "$part" "$checksum"; then
      rm -f -- "$part"
      die "The download does not match the published checksum, so it was deleted."
    fi
    mv -- "$part" "$path"
  fi
  iso_path=$path
}

# Sets iso_path to an ISO the user selects from this computer.
choose_local_iso() {
  local options=() path
  shopt -s nullglob
  options=("$DOWNLOAD_DIR"/*.iso)
  shopt -u nullglob

  choose 'Which ISO?' 0 "${options[@]}" 'Enter another path'
  if (( choice <= ${#options[@]} )); then
    path=${options[choice - 1]}
  else
    ask 'Path to the ISO: '
    path=${answer/#\~/$HOME}
  fi
  [[ -f $path ]] || die "$path is not a file."
  [[ $(read_iso_bytes "$path" 32769 5) == 'CD001' ]] || die "$path is not an ISO image."
  iso_path=$path
}

read_iso_bytes() {
  dd if="$1" bs=1 skip="$2" count="$3" 2> /dev/null | tr -d '\0'
}

verify_local_iso() {
  local checksum
  if [[ ${iso_path##*/} == omarchy-*.iso ]] && checksum=$(published_checksum "${iso_path##*/}"); then
    matches_checksum "$iso_path" "$checksum" ||
      die "$iso_path does not match the published checksum."
  else
    printf '\nWarning: there is no published checksum for this ISO, so it cannot be verified.\n'
  fi
}

choose_iso() {
  local page='' x86_name='' arch name
  printf 'Looking up the latest Omarchy version...\n'
  page=$(curl -fsSL "$SITE_URL" 2> /dev/null) || page=''
  [[ -n $page ]] && x86_name=$(iso_name_on_site "$page" x86)

  if [[ -z $x86_name ]]; then
    printf 'Warning: could not find the latest version on %s. Only ISOs on this computer are available.\n' "$SITE_URL"
    printf 'To use a newer one, download it from that website and choose it here.\n'
    choose_local_iso
    verify_local_iso
    return
  fi

  choose 'Which ISO do you want to write?' 1 \
    "Latest from omarchy.org ($(iso_version "$x86_name"))" \
    'An ISO on this computer'
  if (( choice == 2 )); then
    choose_local_iso
    verify_local_iso
    return
  fi

  choose 'Which architecture is the computer you will install on?' 1 'x86 (most PCs)' 'ARM'
  arch=x86
  (( choice == 2 )) && arch=aarch64
  name=$(iso_name_on_site "$page" "$arch")
  [[ -n $name ]] || die "omarchy.org does not list an ISO for $arch."
  obtain_latest_iso "$name"
}

iso_version() {
  local name=${1##*/}
  if [[ $name =~ ^omarchy-([0-9].*)\.iso$ ]]; then
    name=${BASH_REMATCH[1]}
    name=${name%-x86}
    printf '%s' "${name%-aarch64}"
  else
    printf 'unknown version'
  fi
}

iso_label() {
  local label
  label=$(read_iso_bytes "$1" 32808 32)
  label=${label%"${label##*[![:space:]]}"}
  printf '%s' "${label:-no label}"
}

# Prints the value of a field from a line of lsblk --pairs output.
pair_value() {
  [[ $1 =~ (^|[[:space:]])$2=\"([^\"]*)\" ]] && printf '%s' "${BASH_REMATCH[2]}"
}

drive_labels() {
  local labels
  labels=$(lsblk -nlo LABEL "$1" | sed '/^$/d' | sort -u | tr '\n' ' ')
  printf '%s' "${labels% }"
}

# Sets device and device_identity to a drive the user selects. Only removable USB drives are listed.
choose_drive() {
  local line path devices=() labels=() identities=() model size current
  while true; do
    devices=()
    labels=()
    identities=()
    while IFS= read -r line; do
      [[ $(pair_value "$line" TYPE) == disk ]] || continue
      [[ $(pair_value "$line" RM) == 1 ]] || continue
      [[ $(pair_value "$line" TRAN) == usb ]] || continue
      path=$(pair_value "$line" NAME)
      size=$(pair_value "$line" SIZE)
      model=$(pair_value "$line" MODEL) || model=''
      current=$(drive_labels "$path")
      devices+=("$path")
      identities+=("$line")
      labels+=("$path  $size  ${model:-unknown model}  ${current:-no label}")
    done < <(lsblk -Pdpo "$DRIVE_COLUMNS")

    if (( ${#devices[@]} == 0 )); then
      printf '\nNo removable USB drives found.\n'
    fi
    choose 'Which USB drive do you want to write to?' 0 "${labels[@]}" 'Scan again' 'Cancel'
    if (( choice <= ${#devices[@]} )); then
      device=${devices[choice - 1]}
      device_identity=${identities[choice - 1]}
      return
    fi
    (( choice == ${#devices[@]} + 2 )) && cancel
  done
}

check_drive_capacity() {
  local iso_size drive_size
  iso_size=$(stat -c %s "$iso_path")
  drive_size=$(lsblk -bdno SIZE "$device")
  (( iso_size <= drive_size )) || die "The ISO does not fit on $device."
}

confirm_write() {
  local name=${device##*/}
  printf '\nReady to write:\n'
  printf '  ISO:      %s\n' "$iso_path"
  printf '  Version:  Omarchy %s\n' "$(iso_version "$iso_path")"
  printf '  Label:    %s (the drive gets this name)\n' "$(iso_label "$iso_path")"
  printf '  Drive:    %s\n' "$device"
  printf '\nEverything on this drive will be erased.\n'
  ask "Type $name to continue, or anything else to cancel: "
  [[ $answer == "$name" ]] || cancel
}

# Stops unless the device is still the drive the user confirmed. The name alone
# is not enough, because another disk can take it after a drive is removed.
check_drive_unchanged() {
  local current
  current=$(lsblk -Pdpo "$DRIVE_COLUMNS" "$device" 2> /dev/null) || current=''
  [[ $current == "$device_identity" ]] ||
    die "$device is no longer the drive you chose. Nothing was written."
}

# Sets mountpoints to everything mounted from the drive.
read_mountpoints() {
  local output
  output=$(lsblk -nlo MOUNTPOINTS "$device") ||
    die "Could not check whether $device is mounted. Nothing was written."
  mapfile -t mountpoints < <(sed '/^$/d' <<< "$output")
}

unmount_drive() {
  local mountpoints=() mountpoint
  read_mountpoints
  for mountpoint in "${mountpoints[@]}"; do
    [[ $mountpoint != '[SWAP]' ]] || die "$device is in use as swap. Nothing was written."
    sudo umount "$mountpoint" ||
      die "Could not unmount $mountpoint. Close whatever is using it and run this script again. Nothing was written."
  done
  read_mountpoints
  (( ${#mountpoints[@]} == 0 )) ||
    die "$device is still mounted at ${mountpoints[0]}. Nothing was written."
}

format_size() {
  local tenths=$(( $1 / 100000000 ))
  printf '%d bytes (%d.%d GB)' "$1" $(( tenths / 10 )) $(( tenths % 10 ))
}

write_iso() {
  local size status=0
  size=$(stat -c %s "$iso_path")
  printf '\nThe next steps need administrator rights.\n'
  sudo -v || die "Could not get administrator rights. Nothing was written."
  check_drive_unchanged
  unmount_drive

  sudo bash -c "$WRITE_AND_CHECK" _ "$iso_path" "$device" "$size" "$(format_size "$size")" || status=$?
  case "$status" in
    0) ;;
    10) die "Writing failed, so $device may not boot. Run this script again." ;;
    11) die "Could not read $device to check it, so it may not boot. Run this script again, or try another drive." ;;
    12) die "$device does not match the ISO, so it may not boot. Run this script again, or try another drive." ;;
    *) die "The write may not have finished, so $device may be unchanged or incomplete. Run this script again." ;;
  esac
}

main() {
  local answer='' choice=0 iso_path='' device='' device_identity=''
  check_tools
  choose_iso
  choose_drive
  check_drive_capacity
  confirm_write
  write_iso
  printf '\nDone. %s now has Omarchy %s, labeled %s.\n' \
    "$device" "$(iso_version "$iso_path")" "$(iso_label "$iso_path")"
  printf 'Eject the drive before removing it. On Archon machines, use: arc d eject\n'
}

main "$@"
