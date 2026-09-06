import { homedir } from 'node:os';
import { join } from 'node:path';

import type { GroupContext, WorkspaceAction } from './group-context.ts';
import type { Tmux } from './tmux.ts';
import { manageEditorSessions } from './editor-sessions.ts';

export function manageFlashcards(
  action: WorkspaceAction,
  context: GroupContext<Pick<Tmux, 'hasSession' | 'createEditorSession' | 'stopSession'>>,
) {
  const homeDir = context.homeDir ?? homedir();
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

  return manageEditorSessions(action, sessions, context);
}
