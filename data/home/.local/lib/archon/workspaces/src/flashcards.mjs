import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

import { createEditorSession, hasSession, stopSession } from './tmux.mjs';

export function manageFlashcards(action, context = {}) {
  const directoryExists = context.directoryExists ?? existsSync;
  const homeDir = context.homeDir ?? homedir();
  const printError = context.printError ?? console.error;
  const run = context.run;
  const sessions = [
    {
      session: 'flashcards-fe',
      directory: join(homeDir, 'projects/personal/mrzli/flashcards-fe'),
      devCommand: 'bun run dev',
    },
    {
      session: 'flashcards-be',
      directory: join(homeDir, 'projects/personal/mrzli/flashcards-be'),
      devCommand: 'pnpm run dev',
    },
  ];
  let status = 0;

  for (const definition of sessions) {
    if (action === 'start') {
      if (!directoryExists(definition.directory)) {
        printError(
          `Skipping ${definition.session}: directory does not exist: ${definition.directory}`,
        );
        continue;
      }

      if (hasSession(run, definition.session)) {
        continue;
      }

      if (createEditorSession(run, definition) !== 0) {
        printError(`Failed to start tmux session: ${definition.session}`);
        status = 1;
      }
    } else if (stopSession(run, definition.session) !== 0) {
      printError(`Failed to stop tmux session: ${definition.session}`);
      status = 1;
    }
  }

  return status;
}
