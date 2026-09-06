import { readdirSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, join } from 'node:path';

import type { GroupContext, WorkspaceAction } from './group-context.ts';
import type { Tmux } from './tmux.ts';
import { startEditorSession } from './editor-sessions.ts';

export function manageJslibs(
  action: WorkspaceAction,
  context: GroupContext<Pick<Tmux, 'hasSession' | 'createEditorSession' | 'killSession' | 'listSessions'>>,
): number {
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

function findRepositories(root: string): readonly string[] {
  return readdirSync(root)
    .filter((name): boolean => !name.startsWith('.'))
    .map((name): string => `${join(root, name)}/`)
    .filter((directory): boolean => isDirectory(join(directory, '.git')))
    .sort((left, right): number => left.localeCompare(right));
}

function isDirectory(path: string): boolean {
  try {
    return statSync(path).isDirectory();
  } catch (error) {
    if (error !== null && typeof error === 'object' && 'code' in error && error.code === 'ENOENT') {
      return false;
    }

    throw error;
  }
}
