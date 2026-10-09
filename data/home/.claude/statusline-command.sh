#!/usr/bin/env bash
# Claude Code status line mirroring the starship prompt:
# directory (repo root bold cyan), git branch (italic cyan), git status (cyan),
# followed by context, session (5h), and weekly (7d) usage.

input=$(cat)
dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$dir" ] && dir=$PWD

CYAN=$'\e[36m'
BCYAN=$'\e[1;36m'
ICYAN=$'\e[3;36m'
RST=$'\e[0m'

# Keep at most the last 2 components, prefixing "…/" when truncated.
truncate_path() {
  local p=${1#/} n
  IFS=/ read -r -a parts <<<"$p"
  n=${#parts[@]}
  if [ "$n" -gt 2 ]; then
    printf '…/%s/%s' "${parts[n - 2]}" "${parts[n - 1]}"
  else
    printf '%s' "$p"
  fi
}

root=$(git -C "$dir" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)

out=""
if [ -n "$root" ]; then
  sub=${dir#"$root"}
  base=${root##*/}
  [ -n "$sub" ] && sub=/$(truncate_path "$sub")
  out+="${BCYAN}${base}${RST}${CYAN}${sub}${RST} "

  branch=$(git -C "$dir" --no-optional-locks symbolic-ref --quiet --short HEAD 2>/dev/null \
    || git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && out+="${ICYAN}${branch}${RST} "

  status=$(git -C "$dir" --no-optional-locks status --porcelain=v1 -b 2>/dev/null)
  head=$(printf '%s\n' "$status" | head -n1)
  ahead=0 behind=0
  [[ $head =~ ahead\ ([0-9]+) ]] && ahead=${BASH_REMATCH[1]}
  [[ $head =~ behind\ ([0-9]+) ]] && behind=${BASH_REMATCH[1]}
  files=$(printf '%s\n' "$status" | tail -n +2)

  sym=""
  if printf '%s\n' "$files" | grep -qE '^(DD|AU|UD|UA|DU|AA|UU)'; then sym+=$'\xee\xae\xab '; fi # U+EBAB
  if printf '%s\n' "$files" | grep -q '^??'; then sym+="? "; fi
  if printf '%s\n' "$files" | grep -qE '^.[MTD]'; then sym+=$'\xee\xa9\xb1 '; fi # U+EA71
  if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
    sym+="⇕⇡${ahead}⇣${behind} "
  elif [ "$ahead" -gt 0 ]; then
    sym+="⇡${ahead} "
  elif [ "$behind" -gt 0 ]; then
    sym+="⇣${behind} "
  fi
  [ -z "$sym" ] && sym=$'\xef\x80\x8c ' # U+F00C up_to_date
  [ -n "$sym" ] && out+="${CYAN}${sym}${RST}"
else
  d=${dir/#"$HOME"/\~}
  if [ "$d" = "~" ]; then
    out+="${CYAN}~${RST}"
  else
    d=$(truncate_path "$d")
    case ${dir#"$HOME"} in "$dir") d="/$d" ;; esac
    out+="${CYAN}${d}${RST}"
  fi
fi

# Each value is absent until Claude Code reports it; rate limits need a subscription.
usage=$(printf '%s' "$input" | jq -r '
  [["ctx", (.context_window.used_percentage | values | round)],
   ["5h", (.rate_limits.five_hour.used_percentage | values | round)],
   ["7d", (.rate_limits.seven_day.used_percentage | values | round)]]
  | map(select(length == 2) | "\(.[0]) \(.[1])%") | join(" · ")')
# The git segment already ends with a space.
if [ -n "$usage" ]; then
  [ -z "$root" ] && out+=" "
  out+="${CYAN}${usage}${RST}"
fi

printf '%s' "$out"
