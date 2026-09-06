import { lstatSync } from 'node:fs';
import { join } from 'node:path';

export function isGitRepository(directory: string): boolean {
  return pathExists(join(directory, '.git'));
}

export function pathExists(path: string): boolean {
  try {
    lstatSync(path);
    return true;
  } catch (error) {
    if (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      error.code === 'ENOENT'
    ) {
      return false;
    }

    throw error;
  }
}
