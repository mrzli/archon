import type { Tmux } from './tmux.ts';

export type WorkspaceAction = 'start' | 'stop';

export interface GroupContext<Operations = Tmux> {
  readonly tmux: Operations;
  readonly homeDir?: string;
  readonly directoryExists?: (directory: string) => boolean;
  readonly listRepositories?: (root: string) => readonly string[];
  readonly printError?: (message: string) => void;
}
