# Idea: group Archon library directories

Status: not planned.

Setup installs two directories under `~/.local/lib`: `archon` for the CLI and
`archon-docker` for the rootless Docker launcher. They could be grouped under
one parent, as the data directories are under `~/.local/share/archon`. This
would need a separate migration script for existing workstations.
