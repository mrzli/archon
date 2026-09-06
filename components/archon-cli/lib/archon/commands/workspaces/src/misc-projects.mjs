import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

import { createEditorSession, hasSession, stopSession } from './tmux.mjs';

const PROJECTS = [
  'mrzli/docs',
  'mrzli/repos',
  'mrzli/archon',
  'mrzli/js-templates',
];

export function manageMiscProjects(action, context = {}) {
  const directoryExists = context.directoryExists ?? existsSync;
  const homeDir = context.homeDir ?? homedir();
  const printError = context.printError ?? console.error;
  const run = context.run;
  const root = join(homeDir, 'projects/personal');
  let status = 0;

  for (const project of PROJECTS) {
    const definition = {
      session: `project-${project.replaceAll('/', '-')}`,
      directory: join(root, project),
    };

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

      const result = createEditorSession(run, definition);
      if (result.status !== 0) {
        printError(`Failed to start tmux session: ${definition.session}`);
        if (result.cleanupStatus !== undefined && result.cleanupStatus !== 0) {
          printError(`Failed to clean up tmux session: ${definition.session}`);
        }
        status = 1;
      }
    } else if (stopSession(run, definition.session) !== 0) {
      printError(`Failed to stop tmux session: ${definition.session}`);
      status = 1;
    }
  }

  return status;
}
