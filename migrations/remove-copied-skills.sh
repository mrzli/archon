#!/usr/bin/env bash

set -euo pipefail

# Run manually before setup.sh to replace the old skill copies with links.
# This deletes the listed directories, including any local edits inside them.
for skill in .agents/skills/{elif,explore,handoff,hello,teach,tidy-docs} \
  .agents/skills/{writing-agents,writing-skills,writing-text,interrogate} \
  .codex/skills/hello-archon; do
  skill_path="${HOME:?HOME must be set}/$skill"
  if [[ -d "$skill_path" && ! -L "$skill_path" ]]; then
    rm -r -- "$skill_path"
    printf 'Removed %s\n' "$skill_path"
  fi
done

printf 'Cleanup complete. Run ./setup.sh from the Archon repository to install skill links.\n'
