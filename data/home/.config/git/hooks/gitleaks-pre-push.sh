#!/usr/bin/env bash

# Blocks a push when gitleaks finds a secret in the commits being pushed.
# Git runs it as a configured pre-push hook (hook.gitleaks in ~/.config/git/config),
# before the repository's own pre-push hook.

set -euo pipefail

remote=$1

if ! command -v gitleaks >/dev/null 2>&1; then
  printf '%s\n' 'gitleaks is not installed, so the push is blocked. Run setup, or bypass once with git push --no-verify.' >&2
  exit 1
fi

zero=$(git hash-object --stdin </dev/null | tr '0-9a-f' '0')

# Each line describes one ref: local ref, local commit, remote ref, remote commit.
while read -r _ local_oid _ remote_oid; do
  # A deleted ref pushes no commits.
  [[ $local_oid == "$zero" ]] && continue
  # Scan the commits that the remote's tracked branches, as of the last fetch, do
  # not hold. This also covers new refs and forced pushes.
  log_opts="$local_oid --not --remotes=$remote"
  # Also exclude the ref's current remote commit when it exists locally, which
  # matters when pushing to a URL instead of a named remote.
  if [[ $remote_oid != "$zero" ]] && git cat-file -e "$remote_oid^{commit}" 2>/dev/null; then
    log_opts+=" $remote_oid"
  fi
  # gitleaks gets no stdin, so it cannot consume the remaining ref lines.
  if ! gitleaks git --no-banner --verbose --redact --log-opts="$log_opts" . </dev/null; then
    printf '%s\n' 'gitleaks found a possible secret in the pushed commits, so the push is blocked.' \
      'Remove it from the commits, or record a false positive in .gitleaksignore.' >&2
    exit 1
  fi
done
