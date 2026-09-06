import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

import { hasSession, stopSession } from './tmux.mjs';

export function manageGeneral(action, context = {}) {
  const directoryExists = context.directoryExists ?? existsSync;
  const homeDir = context.homeDir ?? homedir();
  const printError = context.printError ?? console.error;
  const run = context.run;
  const session = 'main';
  const directory = join(homeDir, 'projects');

  if (action === 'start') {
    if (!directoryExists(directory)) {
      printError(`Skipping ${session}: directory does not exist: ${directory}`);
      return 0;
    }

    if (hasSession(run, session)) {
      return 0;
    }

    if (run('tmux', [
      'new-session', '-d', '-s', session, '-c', directory, '-n', 'shell',
    ]) !== 0) {
      printError(`Failed to start tmux session: ${session}`);
      return 1;
    }
  } else if (stopSession(run, session) !== 0) {
    printError(`Failed to stop tmux session: ${session}`);
    return 1;
  }

  return 0;
}
