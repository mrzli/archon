import { existsSync } from 'node:fs';

import { createEditorSession, hasSession, stopSession } from './tmux.mjs';

export function manageEditorSessions(action, definitions, context = {}) {
  const directoryExists = context.directoryExists ?? existsSync;
  const printError = context.printError ?? console.error;
  let status = 0;

  for (const definition of definitions) {
    if (action === 'start') {
      if (!directoryExists(definition.directory)) {
        printError(
          `Skipping ${definition.session}: directory does not exist: ${definition.directory}`,
        );
        continue;
      }

      if (startEditorSession(definition, context) !== 0) {
        status = 1;
      }
    } else if (stopSession(context.run, definition.session) !== 0) {
      printError(`Failed to stop tmux session: ${definition.session}`);
      status = 1;
    }
  }

  return status;
}

export function startEditorSession(definition, context = {}) {
  const printError = context.printError ?? console.error;

  if (hasSession(context.run, definition.session)) {
    return 0;
  }

  const result = createEditorSession(context.run, definition);

  if (result.status !== 0) {
    printError(`Failed to start tmux session: ${definition.session}`);
    if (result.cleanupStatus !== undefined && result.cleanupStatus !== 0) {
      printError(`Failed to clean up tmux session: ${definition.session}`);
    }
    return 1;
  }

  return 0;
}
