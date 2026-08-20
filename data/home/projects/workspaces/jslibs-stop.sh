#!/usr/bin/env bash

tmux list-sessions -F '#S' 2>/dev/null |
  grep -E '^(jslibs|jslib-.*)$' |
  while read -r session; do
    tmux kill-session -t "$session"
  done
