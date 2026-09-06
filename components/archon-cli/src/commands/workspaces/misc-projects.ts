import { homedir } from 'node:os';
import { join } from 'node:path';

import type { GroupContext, WorkspaceAction } from './group-context.ts';
import type { Tmux } from './tmux.ts';
import { manageEditorSessions } from './editor-sessions.ts';

const PROJECTS = [
  'mrzli/docs',
  'mrzli/repos',
  'mrzli/archon',
  'mrzli/js-templates',
];

export function manageMiscProjects(
  action: WorkspaceAction,
  context: GroupContext<Pick<Tmux, 'hasSession' | 'createEditorSession' | 'stopSession'>>,
) {
  const homeDir = context.homeDir ?? homedir();
  const root = join(homeDir, 'projects/personal');
  const sessions = PROJECTS.map((project) => ({
    session: `project-${project.replaceAll('/', '-')}`,
    directory: join(root, project),
  }));

  return manageEditorSessions(action, sessions, context);
}
