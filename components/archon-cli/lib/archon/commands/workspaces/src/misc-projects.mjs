import { homedir } from 'node:os';
import { join } from 'node:path';

import { manageEditorSessions } from './editor-sessions.mjs';

const PROJECTS = [
  'mrzli/docs',
  'mrzli/repos',
  'mrzli/archon',
  'mrzli/js-templates',
];

export function manageMiscProjects(action, context = {}) {
  const homeDir = context.homeDir ?? homedir();
  const root = join(homeDir, 'projects/personal');
  const sessions = PROJECTS.map((project) => ({
    session: `project-${project.replaceAll('/', '-')}`,
    directory: join(root, project),
  }));

  return manageEditorSessions(action, sessions, context);
}
