import { existsSync } from 'node:fs';

import type { GroupContext, WorkspaceAction } from './group-context.ts';
import type { EditorSessionDefinition, Tmux } from './tmux.ts';

export function manageEditorSessions(
  action: WorkspaceAction,
  definitions: EditorSessionDefinition[],
  context: GroupContext<Pick<Tmux, 'hasSession' | 'createEditorSession' | 'stopSession'>>,
) {
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
    } else if (context.tmux.stopSession(definition.session) !== 0) {
      printError(`Failed to stop tmux session: ${definition.session}`);
      status = 1;
    }
  }

  return status;
}

export function startEditorSession(
  definition: EditorSessionDefinition,
  context: GroupContext<Pick<Tmux, 'hasSession' | 'createEditorSession'>>,
) {
  const printError = context.printError ?? console.error;

  if (context.tmux.hasSession(definition.session)) {
    return 0;
  }

  const result = context.tmux.createEditorSession(definition);

  if (result.status !== 0) {
    printError(`Failed to start tmux session: ${definition.session}`);
    if (result.cleanupStatus !== undefined && result.cleanupStatus !== 0) {
      printError(`Failed to clean up tmux session: ${definition.session}`);
    }
    return 1;
  }

  return 0;
}
