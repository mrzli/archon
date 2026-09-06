import { homedir } from 'node:os';
import { join } from 'node:path';

import type { EditorSessionDefinition, GroupContext, Tmux, WorkspaceAction } from '../shared/index.ts';
import { manageEditorSessions } from '../shared/index.ts';

export function manageFlashcards(
  action: WorkspaceAction,
  context: GroupContext<Pick<Tmux, 'hasSession' | 'createEditorSession' | 'stopSession'>>,
): number {
  const homeDir = context.homeDir ?? homedir();
  const sessions: readonly EditorSessionDefinition[] = [
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
