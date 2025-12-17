import os
import shutil
from pathlib import Path

def setup_config(repo_data_dir):
	repo_data_dir = Path(repo_data_dir)
	source_config_dir = repo_data_dir / "config"

	if not source_config_dir.is_dir():
		raise FileNotFoundError(f"Config directory not found: {source_config_dir}")

	xdg_config_home = Path(
		os.environ.get("XDG_CONFIG_HOME")
		or (Path.home() / ".config")
	)
	xdg_config_home.mkdir(parents=True, exist_ok=True)

	# Copy each top-level directory from repo data/config into XDG_CONFIG_HOME.
	for entry in sorted(source_config_dir.iterdir(), key=lambda p: p.name):
		if not entry.is_dir():
			continue

		target = xdg_config_home / entry.name
		if target.exists():
			shutil.rmtree(target)

		shutil.copytree(entry, target)


def remove_config():
	xdg_config_home = Path(
		os.environ.get("XDG_CONFIG_HOME")
		or (Path.home() / ".config")
	)

	if not xdg_config_home.exists():
		return

	for entry in xdg_config_home.iterdir():
		try:
			if entry.is_symlink() or entry.is_file():
				entry.unlink(missing_ok=True)
			elif entry.is_dir():
				shutil.rmtree(entry)
			else:
				# Fallback for special files.
				entry.unlink(missing_ok=True)
		except FileNotFoundError:
			# Race / already deleted.
			pass
