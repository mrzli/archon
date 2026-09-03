# ARC-005: Install the initial Archon command and alias

Status: proposed

Area: Installation

Depends on: ARC-004

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Install `archon` and `a` alongside all legacy commands through the unchanged
home overlay.

## Acceptance checklist

- [ ] Tool files live beneath `data/home/.local/bin` and `data/home/.local/lib/archon`.
- [ ] `a` is a relative symlink to `archon`.
- [ ] `.local/lib/archon` is listed in `data/home-replace-directories.txt`.
- [ ] The existing `cp -a` overlay installs both command paths repeat-safely.
- [ ] Transitional copying may include tool development metadata.
- [ ] No ignore-list or copy-mechanism change is included.
- [ ] No legacy command is removed.

## Verification

- Copy the overlay twice into a temporary home and invoke both command names.
- Verify `--delete-managed-home-dirs` replaces `.local/lib/archon` without
  removing sibling directories.
- Run `bash -n setup.sh` and `git diff --check`.
