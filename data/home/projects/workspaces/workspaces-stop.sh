#!/usr/bin/env bash

tmux kill-session -t libs 2>/dev/null || true
tmux kill-session -t projects 2>/dev/null || true
tmux kill-session -t workspaces 2>/dev/null || true
