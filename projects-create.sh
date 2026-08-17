#!/usr/bin/env bash

set -euo pipefail

# Organizations listed here must be active organizations owned by the
# authenticated GitHub user. Repositories from these organizations are not
# fetched.
ORG_BLACKLIST=(
  # "example-org"
  "mrzli-courses"
  "mrzli-gh-actions"
  "mrzli-other"
  "mrzli-vscode-extensions"
)

# Entries must use the canonical "owner/repository" name. This blacklist is
# applied after personal and non-blacklisted organization repositories have
# been fetched.
REPO_BLACKLIST=(
  # "example-owner/example-repository"
)

usage() {
  cat <<'EOF'
Usage: projects-create.sh [-n|--dry-run]

Options:
  -n, --dry-run Validate and list repositories without creating or cloning.
  -h, --help Show this help.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

capture_gh() {
  local result_variable="$1"
  shift
  local output

  if ! output="$(gh api --hostname github.com "$@")"; then
    return 1
  fi

  printf -v "$result_variable" '%s' "$output"
}

add_repository_rows() {
  local rows="$1"
  local row id full_name ssh_url archived visibility key

  while IFS= read -r row; do
    [[ -n "$row" ]] || continue

    IFS=$'\t' read -r id full_name ssh_url archived visibility <<< "$row"

    if [[ -z "$id" || -z "$full_name" || -z "$ssh_url" ]]; then
      die "GitHub returned incomplete repository data: $row"
    fi

    key="${full_name,,}"
    repository_rows_by_name["$key"]="$row"
  done <<< "$rows"
}

dry_run=false

while (( $# > 0 )); do
  case "$1" in
    -n | --dry-run)
      dry_run=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      echo >&2
      die "Unknown argument: $1"
      ;;
  esac
  shift
done

command -v gh >/dev/null 2>&1 ||
  die "GitHub CLI (gh) is required but was not found."

command -v git >/dev/null 2>&1 ||
  die "Git is required but was not found."

if ! gh auth status --active --hostname github.com >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Error: GitHub CLI is not authenticated.

Run:
  gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key
EOF
  exit 1
fi

username=""
capture_gh username user --jq '.login' ||
  die "Could not determine the authenticated GitHub user."
[[ -n "$username" ]] ||
  die "GitHub returned an empty username."

owned_org_output=""
capture_gh \
  owned_org_output \
  --paginate \
  'user/memberships/orgs?state=active&per_page=100' \
  --jq '.[] | select(.role == "admin") | .organization.login' ||
  die "Could not fetch owned GitHub organizations."

declare -A owned_org_names=()
while IFS= read -r organization; do
  [[ -n "$organization" ]] || continue
  owned_org_names["${organization,,}"]="$organization"
done <<< "$owned_org_output"

declare -a validation_errors=()
declare -A blacklisted_orgs=()

for organization in "${ORG_BLACKLIST[@]}"; do
  organization_key="${organization,,}"

  if [[ ! "$organization" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
    validation_errors+=(
      "Invalid organization blacklist entry '$organization'."
    )
    continue
  fi

  if [[ -n "${blacklisted_orgs[$organization_key]+present}" ]]; then
    validation_errors+=(
      "Duplicate organization blacklist entry '$organization'."
    )
    continue
  fi

  blacklisted_orgs["$organization_key"]=1

  if [[ -z "${owned_org_names[$organization_key]+present}" ]]; then
    validation_errors+=(
      "Blacklisted organization '$organization' is not an active organization owned by '$username'."
    )
  fi
done

declare -A blacklisted_repositories=()

for full_name in "${REPO_BLACKLIST[@]}"; do
  repository_key="${full_name,,}"

  if [[ ! "$full_name" =~ ^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+$ ]]; then
    validation_errors+=(
      "Invalid repository blacklist entry '$full_name'; expected 'owner/repository'."
    )
    continue
  fi

  if [[ -n "${blacklisted_repositories[$repository_key]+present}" ]]; then
    validation_errors+=(
      "Duplicate repository blacklist entry '$full_name'."
    )
    continue
  fi

  blacklisted_repositories["$repository_key"]=1

  canonical_repository=""
  if ! capture_gh \
    canonical_repository \
    "repos/$full_name" \
    --jq '.full_name'; then
    validation_errors+=(
      "Blacklisted repository '$full_name' does not exist or is not accessible."
    )
    continue
  fi

  if [[ "${canonical_repository,,}" != "$repository_key" ]]; then
    validation_errors+=(
      "Blacklisted repository '$full_name' is now '$canonical_repository'."
    )
    continue
  fi

  owner="${canonical_repository%%/*}"
  owner_key="${owner,,}"
  if [[ "$owner_key" != "${username,,}" &&
        -z "${owned_org_names[$owner_key]+present}" ]]; then
    validation_errors+=(
      "Blacklisted repository '$full_name' is not owned by '$username' or an organization owned by '$username'."
    )
  fi
done

if (( ${#validation_errors[@]} > 0 )); then
  echo "Blacklist validation failed:" >&2
  printf '  - %s\n' "${validation_errors[@]}" >&2
  echo >&2
  echo "No repositories were cloned and no local projects were removed." >&2
  exit 1
fi

repository_query='
  .[] |
  [
    .id,
    .full_name,
    .ssh_url,
    .archived,
    (.visibility // (if .private then "private" else "public" end))
  ] |
  @tsv
'
declare -A repository_rows_by_name=()

personal_repository_rows=""
capture_gh \
  personal_repository_rows \
  --paginate \
  'user/repos?affiliation=owner&visibility=all&per_page=100' \
  --jq "$repository_query" ||
  die "Could not fetch repositories owned by '$username'."
add_repository_rows "$personal_repository_rows"

mapfile -t owned_organizations < <(
  printf '%s\n' "${owned_org_names[@]}" | sed '/^$/d' | sort -f
)

for organization in "${owned_organizations[@]}"; do
  organization_key="${organization,,}"
  if [[ -n "${blacklisted_orgs[$organization_key]+present}" ]]; then
    continue
  fi

  organization_repository_rows=""
  capture_gh \
    organization_repository_rows \
    --paginate \
    "orgs/$organization/repos?type=all&per_page=100" \
    --jq "$repository_query" ||
    die "Could not fetch repositories owned by organization '$organization'."
  add_repository_rows "$organization_repository_rows"
done

for repository_key in "${!blacklisted_repositories[@]}"; do
  unset 'repository_rows_by_name[$repository_key]'
done

mapfile -t repository_names < <(
  printf '%s\n' "${!repository_rows_by_name[@]}" | sed '/^$/d' | sort -f
)

if (( ${#repository_names[@]} == 0 )); then
  echo "No repositories remain after applying the blacklists."
  exit 0
fi

home_dir="$(realpath -m -- "${HOME:?HOME is not set}")"
[[ "$home_dir" != "/" ]] ||
  die "Refusing to use the filesystem root as the home directory."

projects_dir="$home_dir/projects"

if [[ -e "$projects_dir" && ! -d "$projects_dir" ]]; then
  die "Projects path exists but is not a directory: $projects_dir"
fi

declare -a existing_destinations=()

for repository_key in "${repository_names[@]}"; do
  row="${repository_rows_by_name[$repository_key]}"
  IFS=$'\t' read -r _ full_name _ _ _ <<< "$row"
  destination="$projects_dir/personal/$full_name"

  if [[ -e "$destination" || -L "$destination" ]]; then
    existing_destinations+=("$destination")
  fi
done

echo
echo "Repositories to clone (${#repository_names[@]}):"
for repository_key in "${repository_names[@]}"; do
  row="${repository_rows_by_name[$repository_key]}"
  IFS=$'\t' read -r _ full_name _ archived visibility <<< "$row"

  attributes=()
  [[ "$visibility" == "public" ]] || attributes+=("$visibility")
  [[ "$archived" == "true" ]] && attributes+=("archived")

  if (( ${#attributes[@]} > 0 )); then
    attribute_list="${attributes[*]}"
    attribute_list="${attribute_list// /, }"
    printf '  - %s (%s)\n' "$full_name" "$attribute_list"
  else
    printf '  - %s\n' "$full_name"
  fi
done

if (( ${#existing_destinations[@]} > 0 )); then
  echo >&2
  echo "Repository destinations already exist:" >&2
  printf '  - %s\n' "${existing_destinations[@]}" >&2
  echo >&2
  echo "Move or remove them manually, then run this script again." >&2
  echo "No repositories were cloned and no local projects were removed." >&2
  exit 1
fi

echo
if [[ "$dry_run" == "true" ]]; then
  echo "Repositories would be cloned under '$projects_dir/personal/<owner>/<repository>'."
  echo "Dry run complete. No local projects were changed."
  exit 0
fi

echo "Repositories will be cloned under '$projects_dir/personal/<owner>/<repository>'."
confirmation=""
read -rp "Continue? (y/N): " confirmation || true

if [[ ! "$confirmation" =~ ^[yY](es)?$ ]]; then
  echo "Aborting. No local projects were changed."
  exit 0
fi

mkdir -p "$projects_dir/personal"

declare -a clone_failures=()

for repository_key in "${repository_names[@]}"; do
  row="${repository_rows_by_name[$repository_key]}"
  IFS=$'\t' read -r _ full_name ssh_url _ _ <<< "$row"
  owner="${full_name%%/*}"
  repository="${full_name#*/}"
  destination="$projects_dir/personal/$owner/$repository"

  mkdir -p "$projects_dir/personal/$owner"
  echo
  echo "Cloning: $full_name"

  if ! git clone "$ssh_url" "$destination"; then
    clone_failures+=("$full_name")
  fi
done

if (( ${#clone_failures[@]} > 0 )); then
  echo >&2
  echo "Failed to clone ${#clone_failures[@]} repositories:" >&2
  printf '  - %s\n' "${clone_failures[@]}" >&2
  exit 1
fi

echo
echo "Cloned ${#repository_names[@]} repositories into '$projects_dir/personal'."
