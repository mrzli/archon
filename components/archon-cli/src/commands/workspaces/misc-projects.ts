import { homedir } from 'node:os';
import { join } from 'node:path';

import type { GroupContext, WorkspaceAction } from './group-context.ts';
import type { EditorSessionDefinition, Tmux } from './tmux.ts';
import { manageEditorSessions } from './editor-sessions.ts';

const PROJECTS: readonly string[] = [
  'mrzli/docs',
  'mrzli/repos',
  'mrzli/learning',
  'mrzli/archon',
  'mrzli/js-templates',
];

export function manageMiscProjects(
  action: WorkspaceAction,
  context: GroupContext<Pick<Tmux, 'hasSession' | 'createEditorSession' | 'stopSession'>>,
): number {
  const homeDir = context.homeDir ?? homedir();
  const root = join(homeDir, 'projects/personal');
  const sessions: readonly EditorSessionDefinition[] = PROJECTS.map((project): EditorSessionDefinition => ({
    session: `project-${project.replaceAll('/', '-')}`,
    directory: join(root, project),
  }));

  return manageEditorSessions(action, sessions, context);
}
