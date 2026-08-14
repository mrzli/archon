#!/usr/bin/env bash

tmux kill-session -t flashcards-fe 2>/dev/null || true
tmux kill-session -t flashcards-be 2>/dev/null || true
