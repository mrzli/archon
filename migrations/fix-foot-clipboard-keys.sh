#!/usr/bin/env bash

set -euo pipefail

# Run manually once on each machine. Omarchy 4.5.0 makes Super+C and Super+V
# send Ctrl+Shift+C and Ctrl+Shift+V to terminals, which a foot.ini that binds
# only the Insert shortcuts ignores. This restores Omarchy's default bindings.
# It matches only those exact lines, so running it on a correct or customized
# file, or again, changes nothing. A machine without the file is skipped.
foot_config="$HOME/.config/foot/foot.ini"

if [[ -f $foot_config ]]; then
  sed -i \
    -e 's/^clipboard-copy=Control+Insert$/clipboard-copy=Control+Insert Control+Shift+c XF86Copy/' \
    -e 's/^clipboard-paste=Shift+Insert$/clipboard-paste=Shift+Insert Control+Shift+v XF86Paste/' \
    "$foot_config"

  # A line this script does not recognize stays as it is, but Super+C or Super+V
  # will not work until it binds the keys that Omarchy sends.
  if grep -Pq '^clipboard-copy=(?!.*Control\+Shift\+c)|^clipboard-paste=(?!.*Control\+Shift\+v)' "$foot_config"; then
    printf 'Warning: %s has clipboard lines without Control+Shift+c or Control+Shift+v. Add those keys by hand.\n' "$foot_config" >&2
    exit 1
  fi
fi

printf 'Foot clipboard keys are up to date. Open a new foot window to use them.\n'
