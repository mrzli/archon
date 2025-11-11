#!/usr/bin/env bash

clear

repo_name="archon"

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

local_repo_path="$XDG_DATA_HOME/$repo_name"

cd "$local_repo_path/arch-install"
./main.sh
cd -
