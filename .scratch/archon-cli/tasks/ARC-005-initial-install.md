# ARC-005: Install the initial Archon command and alias

Status: completed

Area: Installation

Depends on: ARC-004

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Install `archon` and `a` alongside all legacy commands through the unchanged
home overlay.

## Acceptance checklist

- [x] Tool files live beneath `data/home/.local/bin` and `data/home/.local/lib/archon`.
- [x] `a` is a relative symlink to `archon`.
- [x] `.local/lib/archon` is listed in `data/home-replace-directories.txt`.
- [x] The existing `cp -a` overlay installs both command paths repeat-safely.
- [x] Transitional copying may include tool development metadata.
- [x] No ignore-list or copy-mechanism change is included.
- [x] No legacy command is removed.

## Verification

- Copy the overlay twice into a temporary home and invoke both command names.
- Verify `--delete-managed-home-dirs` replaces `.local/lib/archon` without
  removing sibling directories.
- Run `bash -n setup.sh` and `git diff --check`.

## Verification evidence

Added the relative `data/home/.local/bin/a -> archon` symlink and registered
`.local/lib/archon` in `data/home-replace-directories.txt`. `setup.sh` and its
existing `cp -a` operation were not changed.

The focused installation test copied the home overlay twice into a temporary
home, invoked identical help through `archon` and `a`, and confirmed that
development metadata is still copied during this transitional phase. It also
simulated the existing replacement-directory operation and confirmed stale
content was removed only from `.local/lib/archon`, while a sibling library
directory remained intact.

Both installation-layout tests, all four root-command tests, all four
projects/libraries baseline tests, and all seven tmux-workspace tests passed.
Relevant Bash and Node syntax checks and `git diff --check` passed; ShellCheck
was unavailable.
