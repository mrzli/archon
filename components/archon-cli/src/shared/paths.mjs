import { lstatSync } from 'node:fs';
import { join } from 'node:path';

export function isGitRepository(directory) {
  return pathExists(join(directory, '.git'));
}

export function pathExists(path) {
  try {
    lstatSync(path);
    return true;
  } catch (error) {
    if (error?.code === 'ENOENT') {
      return false;
    }

    throw error;
  }
}
