import { readdirSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, join } from 'node:path';

import { startEditorSession } from './editor-sessions.mjs';

export function manageJslibs(action, context = {}) {
  const directoryExists = context.directoryExists ?? isDirectory;
  const homeDir = context.homeDir ?? homedir();
  const listRepositories = context.listRepositories ?? findRepositories;
  const printError = context.printError ?? console.error;
  const tmux = context.tmux;
  const root = join(homeDir, 'projects/personal/mrzli-jslib');

  if (action === 'start') {
    if (!directoryExists(root)) {
      printError(
        `Skipping JavaScript libraries: directory does not exist: ${root}`,
      );
      return 0;
    }

    let status = 0;

    for (const directory of listRepositories(root)) {
      const session = `jslib-${basename(directory)}`;

      if (startEditorSession({ session, directory }, context) !== 0) {
        status = 1;
      }
    }

    return status;
  }

  const result = tmux.listSessions();

  if (result.status !== 0) {
    if (result.output.includes('no server running')) {
      return 0;
    }

    printError(`Failed to list tmux sessions: ${result.output}`);
    return 1;
  }

  let status = 0;

  for (const session of result.output.split('\n')) {
    if (!session.startsWith('jslib-')) {
      continue;
    }

    if (tmux.killSession(session) !== 0) {
      printError(`Failed to stop tmux session: ${session}`);
      status = 1;
    }
  }

  return status;
}

function findRepositories(root) {
  return readdirSync(root)
    .filter((name) => !name.startsWith('.'))
    .map((name) => `${join(root, name)}/`)
    .filter((directory) => isDirectory(join(directory, '.git')))
    .sort((left, right) => left.localeCompare(right));
}

function isDirectory(path) {
  try {
    return statSync(path).isDirectory();
  } catch (error) {
    if (error?.code === 'ENOENT') {
      return false;
    }

    throw error;
  }
}
