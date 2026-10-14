# Drives command

List and eject removable drives, such as USB flash drives. `d` aliases
`drives`. Udiskie mounts drives automatically when they are plugged in, so
there is no mount command.

## Eject

Requires `lsblk`, `udisksctl`, and an interactive terminal. No sudo is needed.

```bash
arc d eject
```

Choose a drive with `j`/`k` or Up/Down and press Enter. Escape or Ctrl+C
cancels. The picker lists physical drives, not partitions, with their size,
device path, and partition labels.

Eject unmounts every mounted filesystem on the chosen drive and then powers the
drive off, after which it is safe to remove. If a filesystem is busy, for
example because a shell is inside it or a file is open, eject reports the error
and leaves the drive powered on. Close whatever uses it and run eject again.
Encrypted drives are not unlocked or locked.

## List

Requires `lsblk`.

```bash
arc d list
```

Shows each removable drive with its name, size, and device path, followed by
its filesystems with label, type, and mount points, or `not mounted`.
Internal disks are not shown.
