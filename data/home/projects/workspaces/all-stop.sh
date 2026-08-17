#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/other-stop.sh"
"$SCRIPT_DIR/jslibs-stop.sh"
"$SCRIPT_DIR/flashcards-stop.sh"
"$SCRIPT_DIR/workspaces-stop.sh"
