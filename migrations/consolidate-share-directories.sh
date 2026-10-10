#!/usr/bin/env bash

set -euo pipefail

# Run manually once per machine before setup.sh. Archon's data now lives in
# ${XDG_DATA_HOME:-~/.local/share}/archon/{repo,skills,secrets}. This removes the
# old bootstrap clone at archon/, the old skills checkout at archon-skills/, and
# the skill links into it. Setup clones the skills again and recreates the links.
data_home="${XDG_DATA_HOME:-${HOME:?HOME must be set}/.local/share}"
old_repo="$data_home/archon"
old_skills="$data_home/archon-skills"

# The old checkouts may be deleted while this script runs from one of them.
cd /

# Refuses to discard local work. A path without .git is not an old checkout:
# after migration, archon/ is the new parent directory and must be kept.
require_clean() {
  local path="$1"
  [[ -d "$path/.git" ]] || return 0
  if [[ -n "$(git -C "$path" status --porcelain)" ||
    -n "$(git -C "$path" log --branches --not --remotes --oneline)" ||
    -n "$(git -C "$path" stash list)" ]]; then
    printf 'Refusing to remove %s: it has uncommitted, unpushed, or stashed changes.\n' "$path" >&2
    exit 1
  fi
}

require_clean "$old_repo"
require_clean "$old_skills"

for directory in "$HOME/.agents/skills" "$HOME/.claude/skills"; do
  [[ -d "$directory" ]] || continue
  find "$directory" -maxdepth 1 -type l -lname "$old_skills/*" -printf 'Removed link %p\n' -delete
done

for path in "$old_repo" "$old_skills"; do
  if [[ -d "$path/.git" ]]; then
    rm -rf -- "$path"
    printf 'Removed %s\n' "$path"
  fi
done

printf 'Migration complete. Run ./setup.sh from an Archon checkout.\n'
printf 'To keep a bootstrap clone, clone it into %s/repo as the README describes.\n' "$old_repo"
