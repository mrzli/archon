import type { Tmux } from './tmux.ts';

export type WorkspaceAction = 'start' | 'stop';

export interface GroupContext<Operations = Tmux> {
  tmux: Operations;
  homeDir?: string;
  directoryExists?: (directory: string) => boolean;
  listRepositories?: (root: string) => string[];
  printError?: (message: string) => void;
}
