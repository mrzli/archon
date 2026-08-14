#!/usr/bin/env bash

PROJECTS=(
  "mrzli/docs"
  "mrzli/repos"
  "mrzli/archon"
  "mrzli/js-templates"
)

for project in "${PROJECTS[@]}"; do
  session="project-${project//\//-}"

  tmux kill-session -t "$session" 2>/dev/null || true
done

