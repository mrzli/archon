import { homedir } from 'node:os';
import { join } from 'node:path';

import { manageEditorSessions } from './editor-sessions.mjs';

export function manageFlashcards(action, context = {}) {
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
