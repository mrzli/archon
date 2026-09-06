import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

import type { GroupContext, Tmux, WorkspaceAction } from '../shared/index.ts';

export function manageGeneral(
  action: WorkspaceAction,
  context: GroupContext<Pick<Tmux, 'hasSession' | 'createShellSession' | 'stopSession'>>,
): number {
  const directoryExists = context.directoryExists ?? existsSync;
  const homeDir = context.homeDir ?? homedir();
  const printError = context.printError ?? console.error;
  const tmux = context.tmux;
  const session = 'main';
  const directory = join(homeDir, 'projects');

  if (action === 'start') {
    if (!directoryExists(directory)) {
      printError(`Skipping ${session}: directory does not exist: ${directory}`);
      return 0;
    }

    if (tmux.hasSession(session)) {
      return 0;
    }

    if (tmux.createShellSession({ session, directory }) !== 0) {
      printError(`Failed to start tmux session: ${session}`);
      return 1;
    }
  } else if (tmux.stopSession(session) !== 0) {
    printError(`Failed to stop tmux session: ${session}`);
    return 1;
  }

  return 0;
}
